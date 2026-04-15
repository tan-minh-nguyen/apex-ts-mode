;;; apex-consult.el --- Integrate apex to consult -*- lexical-binding: t -*-

;; Copyright (C) 2025 Tan Nguyen

;; Author: Tan Nguyen <tan.nguyen.w.information@gmail.com>
;; Version: 1.0.0
;; Package-Requires: ((emacs "29.1") (apex-ts-mode "1.0") (consult "0.35") (marginalia "1.0") (nerd-icons "0.1.0"))

;; Keywords: salesforce, apex, consult
;; URL: https://github.com/tan-minh-nguyen/apex-ts-mode

;;; Commentary:
;; This package provides consult integration for Apex mode,
;; enabling quick navigation through Apex code structures.
;; Requires salesforce-minor-mode for salesforce-consult macros.

;;; Code:

(require 'cl-lib)
(require 'consult)
(require 'marginalia)
(require 'nerd-icons)
(require 'treesit)

(defgroup apex-consult nil
  "Consult integration for Apex mode."
  :group 'apex
  :prefix "apex-consult-")

(defcustom apex-consult-icon-alist
  '(("Class" . "nf-cod-symbol_class")
    ("Method" . "nf-cod-symbol_method")
    ("Field" . "nf-cod-symbol_field")
    ("Enum" . "nf-cod-symbol_enum")
    ("Property" . "nf-cod-symbol_property")
    ("Interface" . "nf-cod-symbol_interface"))
  "Alist mapping imenu category names to nerd-icons codicon names."
  :type '(alist :key-type string :value-type string)
  :group 'apex-consult)

(defun apex-consult--get-icon (name)
  "Get nerd-icon for category NAME."
  (when-let* ((icon-name (cdr (assoc name apex-consult-icon-alist))))
    (nerd-icons-codicon icon-name)))

(defun apex-consult--make-annotate (name)
  "Create annotate function for category NAME."
  (lambda (_cand)
    (marginalia--fields
     ((propertize (concat "@" name) 'face 'marginalia-type)))))

(defun apex-consult--imenu-state ()
  "Handle imenu state for consult preview."
  (let ((preview (consult--jump-preview)))
    (lambda (action cand)
      (pcase-let ((`(,_ . ,marker) cand))
        (funcall preview action marker)))))

(cl-defun apex-consult--imenu-candidates (regexp &key pred name-fn)
  "Search candidates with tree-sitter REGEXP in the buffer.
PRED and NAME-FN are passed to `treesit--simple-imenu-1'."
  (declare (indent 1))
  (when-let* ((tree (treesit-induce-sparse-tree
                     (treesit-buffer-root-node) regexp)))
    (treesit--simple-imenu-1 tree pred name-fn)))

(defun apex-consult--convert-imenu (imenu-source)
  "Convert IMENU-SOURCE to consult source."
  (pcase-let* ((`(,name ,regexp ,pred ,name-fn) imenu-source)
               (narrow-char (aref name 0))
               (icon (apex-consult--get-icon name))
               (display-name (if icon (concat icon " " name) name)))

    (list :name display-name
       :narrow narrow-char
       :category (intern name)
       :face 'font-lock-variable-name-face
       :action (lambda (marker)
                 (goto-char marker))
       :state #'apex-consult--imenu-state
       :annotate (apex-consult--make-annotate name)
       :items (lambda ()
                (mapcar (pcase-lambda (`(,text . ,marker))
                          (cons (concat (or icon "") " " text) marker))
                        (apex-consult--imenu-candidates regexp
                          :pred pred
                          :name-fn name-fn))))))

;;;###autoload
(defun apex-consult-imenu ()
  "Build consult search from imenu."
  (interactive)
  (consult--multi
   (mapcar #'apex-consult--convert-imenu treesit-simple-imenu-settings)
   :prompt "@"
   :require-match t))

(provide 'apex-consult)

;;; apex-consult.el ends here
