;;; apex-lsp.el --- LSP server for apex-ts-mode -*- lexical-binding: t -*-
;;; Commentary:
;;; Code:

(defcustom apex-lsp-jar nil
  "Path to Apex LSP JAR file."
  :type 'string
  :group 'apex)

(defcustom apex-lsp-eglot-args '(:initializationOptions (:enableEmbeddedSoqlCompletion t))
  "Eglot initialization options for Apex LSP."
  :type 'list
  :group 'apex)

(with-eval-after-load 'eglot
  (push (cons 'apex-ts-mode
              (lambda (&rest _)
                `("java" "-cp" ,(expand-file-name apex-lsp-jar) "apex.jorje.lsp.ApexLanguageServerLauncher"
                  ,@apex-lsp-eglot-args)))
        eglot-server-programs))


(provide 'apex-lsp)
;;; apex-lsp.el ends here
