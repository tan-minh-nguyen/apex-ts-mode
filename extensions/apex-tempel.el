;;; apex-tempel.el --- configuration tempel for Apex mode -*- lexical-binding: t -*-

(defvar apex-tempel-file (expand-file-name "snippets/templates" apex-load-directory)
  "Snippets file for Tempel.")

;;;###autoload
(defun apex-tempel-initialize ()
  "Initialize the tempel setup for `apex-ts-mode'."
  (add-to-list 'tempel-path apex-tempel-file))

(provide 'apex-tempel)
