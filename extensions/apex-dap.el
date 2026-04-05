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

(defcustom apex-dap-replay-debugger-server nil
  "Path to replay debugger server for Apex mode."
  :type 'string
  :group 'apex-dap)

(defvar-local apex-dap-log-file nil
  "Path to log file.")

(defvar-local apex-dap-workspace nil
  "Path to workspace directory for replay debug.")

;;;###autoload
(defun apex-dap-start-replay-debugger ()
  "Start Replay Debugger for Apex mode."
  (interactive)
  (unless (featurep 'dape)
    (user-error "apex-dap requires dape package"))
  (setq-local apex-dap-log-file (read-file-name "File:")
              apex-dap-workspace (projectile-project-root))
  (call-interactively #'dape))

;; Configuration replay-debugger for Apex mode
(defun apex-dap-initialize ()
  "Initialize Apex Replay Debugger server."
  (unless apex-ts-dap-replay-debugger-server
    (error "Please set apex-ts-dap-replay-debugger-server to apex debug adapter."))
  (add-to-list 'dape-configs
               `(apex-replay modes (apex-ts-mode)
                             command "node"
                             command-args `(,(expand-file-name apex-ts-dap-replay-debugger-server) "--stdout")
                             :type "apex-replay"
                             :request "launch"
                             :logFile apex-dap-log-file
                             :projectPath apex-dap-workspace
                             :stopOnEntry t
                             :trace t
                             :languages ["apex"]
                             :lineBreakpointInfo [])))

(provide 'apex-dap)
;;; apex-dap.el ends here
