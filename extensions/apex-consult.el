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

(require 'consult)
(require 'consult-imenu)

(defgroup apex-consult nil
  "Consult integration for Apex mode."
  :group 'apex
  :prefix "apex-consult-")

(with-eval-after-load 'consult-imenu
  (add-to-list 'consult-imenu-config
               '(apex-ts-mode
                 :toplevel nil
                 :types ((?c "Class"     font-lock-type-face)
                         (?i "Interface" font-lock-type-face)
                         (?e "Enum"      font-lock-constant-face)
                         (?m "Method"    font-lock-function-name-face)
                         (?f "Field"     font-lock-variable-name-face)))))

(provide 'apex-consult)

;;; apex-consult.el ends here
