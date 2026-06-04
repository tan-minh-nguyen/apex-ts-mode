;;; ob-apex.el --- Org-babel support for Apex -*- lexical-binding: t -*-

;; Copyright (C) 2024-2026 Tan Nguyen

;; Author: Tan Nguyen <tan.nguyen.w.information@gmail.com>
;; Maintainer: Tan Nguyen <tan.nguyen.w.information@gmail.com>
;; Version: 1.0.0
;; Package-Requires: ((emacs "29.1") (apex-ts-mode "1.0"))
;; Keywords: literate programming, salesforce, apex
;; Homepage: https://github.com/tan-minh-nguyen/apex-ts-mode

;; SPDX-License-Identifier: GPL-3.0-or-later

;;; Commentary:

;; Org-babel support for executing Apex code blocks.
;; Requires salesforce-mode: https://github.com/tan-minh-nguyen/salesforce-minor-mode

;;; Code:

(require 'ob)
(require 'ob-ref)
(require 'ob-comint)
(require 'ob-eval)
(require 'apex-ts-mode)

;; Optional: SOQL query variable integration
(require 'ob-soql-core nil t)

;;; Queue and Timer Infrastructure

(defvar-local ob-apex--queue-jobs nil
  "Queue of pending Apex job IDs waiting for execution.")

(defvar-local ob-apex-timer nil
  "Timer for batched Apex job execution.")

(defcustom ob-apex-throttle 1
  "Seconds to wait before running queued Apex jobs.
Multiple source blocks evaluated within this window are batched together."
  :type 'number
  :group 'ob-apex)

;;; Configuration

(add-to-list 'org-babel-tangle-lang-exts '("apex" . "cls"))
(add-to-list 'org-src-lang-modes '("apex" . apex-ts))
(add-to-list 'org-babel-load-languages '("apex" . t))
;;; Default Header Arguments

(defvar org-babel-default-header-args:apex
  '((:results . "replace")
    (:org . "")
    (:filter-type . "DEBUG")
    (:filter-value . nil))
  "Default header arguments for Apex code blocks.")

(defvar org-babel-default-inline-header-args:apex
  '((:results . "replace")
    (:org . "")
    (:filter-type . "DEBUG")
    (:filter-value . nil))
  "Default header arguments for inline Apex code blocks.")

;;; Filter Keywords

(defvar org-babel-executable-keywords
  '("VARIABLE_ASSIGNMENT"
    "STATEMENT_EXECUTE"
    "METHOD_ENTRY"
    "CONSTRUCTOR_EXIT"
    "CODE_UNIT_STARTED")
  "Keywords used for filtering with Executable type.")

(defvar org-babel-system-keywords
  '("VARIABLE_ASSIGNMENT"
    "STATEMENT_EXECUTE"
    "METHOD_ENTRY"
    "CONSTRUCTOR_EXIT"
    "CODE_UNIT_STARTED")
  "Keywords used for filtering with System type.")

(defvar org-babel-debug-keywords
  '("VARIABLE_ASSIGNMENT"
    "STATEMENT_EXECUTE"
    "METHOD_ENTRY"
    "CONSTRUCTOR_EXIT"
    "CODE_UNIT_STARTED")
  "Keywords used for filtering with Debug type.")

(defvar org-babel-governor-keywords
  '("LIMIT_USAGE_FOR_NS"
    "Number of"
    "Maximum CPU"
    "Maximum heap")
  "Keywords used for filtering with Governor type.")

;;; Constants

(defconst ob-apex--result-types '("none" "value" "output")
  "Valid result types for Apex code blocks.")

(defconst ob-apex--filter-types '("DEBUG" "EXECUTABLE" "SYSTEM" "GOVERNOR")
  "Valid filter types for Apex log output.")

;;; Type Mapping

(defconst ob-apex--type-mapping
  '(("string" . "String")
    ("number" . "Decimal")
    ("boolean" . "Boolean")
    ("object" . "Object"))
  "Mapping from internal type names to Apex type names.")

;;; Body Expansion

(defun org-babel-expand-body:apex (body params &optional processed-params)
  "Expand BODY according to PARAMS, return the expanded body.
PROCESSED-PARAMS can be provided to avoid reprocessing.
This function prepares the Apex code by adding variable declarations
based on the provided parameters.
Supports SOQL query variables when ob-soql-core is loaded."
  (let ((vars (org-babel--get-vars
               (or processed-params
                  (org-babel-process-params params)))))
    (concat
     (mapconcat #'ob-apex--expand-variable vars "\n")
     (when vars "\n")
     body "\n")))

(defun ob-apex--expand-variable (pair)
  "Expand variable PAIR into Apex declaration.
PAIR is (var-name . value).
If ob-soql-core is loaded and value references a SOQL query,
generates type-safe query code. Otherwise uses standard declaration."
  (let* ((var-name (symbol-name (car pair)))
         (value (cdr pair)))
    (cond
     ;; Check if ob-soql-core loaded and value is SOQL query name
     ((and (featurep 'ob-soql-core)
           (stringp value)
           (fboundp 'ob-soql-vars-get-query)
           (ob-soql-vars-get-query value))
      ;; It's a SOQL query - generate type-safe code
      (ob-soql-vars-to-apex-query var-name (ob-soql-vars-get-query value)))

     ;; Standard variable - use existing logic
     (t
      (ob-apex--declare-variable pair)))))

;;; Code Execution

(defun ob-apex--check-salesforce-mode ()
  "Check that salesforce-mode is available, signal error if not."
  (unless (featurep 'salesforce-core)
    (user-error "ob-apex requires salesforce-mode. Install from https://github.com/tan-minh-nguyen/salesforce-minor-mode")))

(defun ob-apex--parser-json (proc)
  "Return a parser function for Apex process output.
The returned function takes a process PROC and returns the filtered log string,
or nil if RESULT-EVAL is \"none\" (display suppressed by caller)."
  (let* ((json (salesforce-core--parse-json proc)))
    (map-nested-elt json '("result" "logs"))))

(cl-defun ob-apex-execute:src (body processed-params)
  "Create a pipeline job for Apex execution.
Returns the job-id used as both the queue key and the #+RESULTS: placeholder.
BODY is the unexpanded Apex code; PROCESSED-PARAMS are org-babel params."
  (let* ((org-name (ob-apex--get-param :org processed-params))
         (result-eval (ob-apex--get-param :results processed-params))
         (filter-type (ob-apex--get-param :filter-type processed-params))
         (filter-value (ob-apex--get-param :filter-value processed-params)))
    
    (emacs-pp-job
     :ready-p nil
     (lambda ()
       (let ((full-body (org-babel-expand-body:apex body processed-params))
             (tempfile (make-temp-file "temp-apex")))
         (prog1 tempfile
           (write-region full-body nil tempfile))))

     (lambda (tempfile)
       (salesforce-core--apex-process
        :args `("run" "-f" ,tempfile "-o" ,org-name "--json")
        :parser #'ob-apex--parser-json))
     (lambda (log-content)
       (unless (ob-apex--result-is-none-p result-eval)
         (ob-apex--filter-log log-content filter-type filter-value)))
     :catch #'salesforce-core--handle-process-error)))

(defun org-babel-execute:apex (body params)
  "Execute a block of Apex code with org-babel.
BODY is the content of the code block.
PARAMS are the header arguments.
Requires salesforce-mode to be installed."
  (ob-apex--check-salesforce-mode)
  (when (timerp ob-apex-timer)
    (cancel-timer ob-apex-timer))
  (let* ((buffer (current-buffer))
         (processed-params (org-babel-process-params params))
         (result-eval (ob-apex--get-param :results processed-params))
         (job-id (ob-apex-execute:src body processed-params))
         (run-seq-jobs
          (lambda (jobs)
            (apply #'emacs-pp-jobs-sequence
                   :complete
                   (lambda (job-results)
                     (let ((log-string (gethash job-id job-results)))
                       (with-current-buffer buffer
                         (setq-local ob-apex--queue-jobs nil)
                         (cancel-timer ob-apex-timer))
                       (when log-string
                         (ob-apex--display-result job-id
                           :content log-string))
                       (alert "Apex code executed"
                              :title "Salesforce Alert")))
                   jobs))))

    (prog1 (unless (ob-apex--result-is-none-p result-eval) job-id)
      (push job-id ob-apex--queue-jobs)
      (setq-local ob-apex-timer
                  (run-with-timer ob-apex-throttle nil
                                  run-seq-jobs
                                  (reverse ob-apex--queue-jobs))))))

;;; Result Handling

(defun ob-apex--result-is-none-p (result-type)
  "Check if RESULT-TYPE indicates no results should be displayed."
  (string-equal-ignore-case result-type "none"))

(cl-defun ob-apex--display-result (job-id &key content (buffer (current-buffer)))
  "In BUFFER, replace the JOB-ID placeholder with CONTENT (filtered log string)."
  (declare (indent 1))
  (when (buffer-live-p buffer)
    (with-current-buffer buffer
      (save-excursion
        (replace-string job-id content nil (point-min) (point-max) t)))))

;;; Log Filtering

(defun ob-apex--filter-log (content type value)
  "Filter CONTENT of the log file based on TYPE and VALUE."
  (let ((filter-fn (ob-apex--get-filter-fn type value)))
    (mapconcat (lambda (line)
                 (when (funcall filter-fn line)
                   (concat line "\n")))
               (split-string content "\n")
               "")))

(defun ob-apex--get-filter-fn (type value)
  "Return the appropriate filter function based on TYPE and VALUE.
The filter function checks if a line matches the specified TYPE
and optionally contains VALUE."
  (let ((base-filter-fn (ob-apex--get-base-filter-fn type)))
    (if (and value (not (string-empty-p value)))
        (lambda (line)
          (and (funcall base-filter-fn line)
             (string-match-p (regexp-quote value) line)))
      base-filter-fn)))

(defun ob-apex--get-base-filter-fn (type)
  "Return the base filter function for TYPE."
  (cond
   ((string-equal-ignore-case type "DEBUG")
    (lambda (line) (string-match-p "DEBUG" line)))
   ((string-equal-ignore-case type "EXECUTABLE")
    (lambda (line) (string-match-p (regexp-opt org-babel-executable-keywords) line)))
   ((string-equal-ignore-case type "SYSTEM")
    (lambda (line) (string-match-p (regexp-opt org-babel-system-keywords) line)))
   ((string-equal-ignore-case type "GOVERNOR")
    (lambda (line) (string-match-p (regexp-opt org-babel-governor-keywords) line)))
   (t (lambda (_) nil))))

;;; Variable Declaration

(defun ob-apex--declare-variable (pair)
  "Generate Apex variable declaration code from PAIR.
PAIR is a cons cell of (variable-name . value)."
  (let ((key (car pair))
        (value (cdr pair)))
    (ob-apex--build-var-code key (format "%s" value))))

(defun ob-apex--build-var-code (key value)
  "Build variable declaration code for Apex.
KEY is the variable name.
VALUE is the variable value."
  (let* ((type (ob-apex--infer-type value))
         (apex-type (ob-apex--get-apex-type type))
         (formatted-value (ob-apex--format-value type value)))
    (format "%s %s = %s;" apex-type key formatted-value)))

;;; Type Inference

(defun ob-apex--infer-type (value)
  "Infer the type of VALUE for Apex variable declaration."
  (cond
   ((string-match-p "^'" value) "string")
   ((string-match-p "^[0-9]+\\(?:\\.[0-9]+\\)?$" value) "number")
   ((string-match-p "^\\(?:[Tt]rue\\|[Ff]alse\\)$" value) "boolean")
   (t "object")))

(defun ob-apex--get-apex-type (type)
  "Get the Apex type corresponding to internal TYPE."
  (or (cdr (assoc type ob-apex--type-mapping))
     "Object"))

(defun ob-apex--format-value (type value)
  "Format VALUE based on its TYPE for Apex variable declaration."
  (pcase type
    ("string" (format "'%s'" (string-trim value "'" "'")))
    ("number" value)
    ("boolean" value)
    (_ (format "new %s()" value))))

(defun ob-apex--get-param (key param-list)
  "Extract the parameter value associated with KEY from PARAM-LIST."
  (cdr (assq key param-list)))

;;; Session Support (Placeholder)

(defun org-babel-prep-session:apex (session params)
  "Prepare SESSION according to the header arguments specified in PARAMS.
This function is currently a placeholder and does not perform any actions.
TODO: Implement session support for Apex."
  (error "Sessions are not yet supported for Apex code blocks"))

;;; Variable Conversion (Placeholder)

(defun org-babel-apex-var-to-apex (var)
  "Convert an elisp VAR into a string of Apex source code.
Specifies a variable of the same value."
  (format "%s" var))

;;; Template Functions (Unused - Consider Removal)

(defun org-babel-apex-table-or-string (results)
  "Convert RESULTS into an Emacs-lisp table or return as a string.
This function is currently a placeholder.
TODO: Implement proper result handling or remove if unused."
  results)

(defun org-babel-apex-initiate-session (&optional session)
  "Create and return an initialized SESSION.
If SESSION already exists, return the existing session.
This function is currently a placeholder.
TODO: Implement session initialization or remove if unused."
  (error "Sessions are not yet supported for Apex code blocks"))

(provide 'ob-apex)

;;; ob-apex.el ends here
