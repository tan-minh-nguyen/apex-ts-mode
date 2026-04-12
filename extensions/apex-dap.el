;;; apex-dap.el --- Debug adapter for Apex -*- lexical-binding: t -*-

;; Copyright (C) 2024-2026 Tan Nguyen

;; Author: Tan Nguyen <tan.nguyen.w.information@gmail.com>
;; Maintainer: Tan Nguyen <tan.nguyen.w.information@gmail.com>
;; Version: 0.1.0
;; Package-Requires: ((emacs "29.1") (dape "0.25.0"))
;; Keywords: languages, apex, salesforce, debug
;; Homepage: https://github.com/tan-minh-nguyen/apex-ts-mode

;; SPDX-License-Identifier: GPL-3.0-or-later

;; STATUS: Work in Progress (WIP)
;; This extension is under development and not yet fully functional.

;;; Commentary:

;; Debug adapter protocol support for Apex using dape.
;; Requires dape package to be installed.

;;; Code:

(defcustom apex-dap-replay-debugger-server (expand-file-name "~/projects/salesforcedx-vscode/packages/salesforcedx-apex-replay-debugger/out/src/adapter/apexReplayDebug.js")
  "Path to replay debugger server for Apex mode."
  :type 'string
  :group 'apex-dap)

(defun apex-dap--project-root ()
  "Get project root, preferring `salesforce-project-root-dir'."
  (project-root (project-current)))

(defun apex-dap--project-classes ()
  "Get all Apex classes in the current project as a hash table."
  (let* ((class-directory (salesforce-project-metadata-path salesforce-project-session 'class))
         (apex-classes (directory-files-recursively class-directory "\\.cls$")))
    (cl-loop with class-table = (make-hash-table :test #'equal)
             for file in apex-classes
             as typeref = (file-name-sans-extension (file-name-nondirectory file))
             do (puthash file
                         (list :uri (concat "file://" file)
                            :typeref typeref
                            :lines [])
                         class-table)
             finally return class-table)))

(defun apex-dap-line-breakpoints ()
  "Get line breakpoint info for Apex debug adapter.
Returns a vector of plists with :uri, :typeref, and :lines properties.
Includes all project classes for source mapping, plus breakpoint lines."
  (cl-loop with class-table = (apex-dap--project-classes)
           for breakpoint in dape--breakpoints
           as file = (dape--breakpoint-file-name breakpoint)
           as line = (dape--breakpoint-line breakpoint)
           as entry = (gethash file class-table)
           when entry
           do (plist-put entry :lines (vconcat (plist-get entry :lines) `[,line]))
           finally return (apply #'vector (hash-table-values class-table))))

(defun apex-dap-get-file-log (config)
  "Function to prompt for log file and inject content into CONFIG."
  (let* ((server-path (expand-file-name apex-dap-replay-debugger-server))
         ;;TODO: use default for of log
         (log-file (read-file-name "Log file: "))
         (log-content
          (with-temp-buffer
            (insert-file-contents log-file)
            (buffer-string))))

    (plist-put config 'command-args (list server-path "--stdout"))
    (plist-put config :logFileContents log-content)
    (plist-put config :logFilePath (expand-file-name log-file))
    (plist-put config :logFileName (file-name-nondirectory log-file))
    (plist-put config :projectPath (apex-dap--project-root))
    (plist-put config :env (list :SFDX_DEFAULTUSERNAME
                              (salesforce-project-org salesforce-project-session)
                              :SF_TARGET_ORG
                              (salesforce-project-org salesforce-project-session)))
    (plist-put config :lineBreakpointInfo (apex-dap-line-breakpoints))
    config))

;; Configuration replay-debugger for Apex mode
(with-eval-after-load 'dape
  (require 'salesforce-core nil :no-error)
  (add-to-list 'dape-configs
               `(apex-replay modes (apex-ts-mode)
                             command "node"
                             command-args nil
                             fn apex-dap-get-file-log
                             :type "apex-replay"
                             :request "launch"
                             :stopOnEntry t
                             :trace t
                             :languages ["apex"]
                             :lineBreakpointInfo [])))

(provide 'apex-dap)
;;; apex-dap.el ends here
