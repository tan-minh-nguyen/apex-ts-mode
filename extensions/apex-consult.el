;;; apex-consult.el --- Integrate apex to consult -*- lexical-binding: t -*-

;; Copyright (C) 2025 Tan Nguyen

;; Author: Tan Nguyen <tan.nguyen.w.information@gmail.com>
;; Version: 1.0.0
;; Package-Requires: ((emacs "29.1") (apex-ts-mode "1.0") (consult "0.35") (nerd-icons "0.1.0"))
;; This file is part of apex-ts-mode extensions.

;; Keywords: salesforce, apex, consult
;; URL: https://github.com/tan-minh-nguyen/apex-ts-mode

;;; Commentary:
;; This package provides consult integration for Apex mode,
;; enabling quick navigation through Apex code structures.
;; Requires salesforce-minor-mode for salesforce-consult macros.

;;; Code:

(require 'nerd-icons nil t)

;; Optional: Salesforce consult integration
(require 'salesforce-core nil t)

(defgroup apex-consult nil
  "Consult integration for Apex mode."
  :group 'apex
  :prefix "apex-consult-")

(defcustom apex-consult-icon-field
  (when (fboundp 'nerd-icons-codicon)
    (nerd-icons-codicon "nf-cod-symbol_variable"))
  "Nerd icon for field consult source."
  :group 'apex-consult
  :type '(choice string null))

(defcustom apex-consult-icon-method
  (when (fboundp 'nerd-icons-codicon)
    (nerd-icons-codicon "nf-cod-symbol_method"))
  "Nerd icon for method consult source."
  :group 'apex-consult
  :type '(choice string null))

(defcustom apex-consult-icon-class
  (when (fboundp 'nerd-icons-codicon)
    (nerd-icons-codicon "nf-cod-symbol_method"))
  "Nerd icon for class consult source."
  :group 'apex-consult
  :type '(choice string null))

(defcustom apex-consult-icon-sobject
  (when (fboundp 'nerd-icons-codicon)
    (nerd-icons-codicon "nf-cod-symbol_field"))
  "Nerd icon for sobject consult source."
  :group 'apex-consult
  :type '(choice string null))

(defcustom apex-consult-icon-enum
  (when (fboundp 'nerd-icons-codicon)
    (nerd-icons-codicon "nf-cod-symbol_enum"))
  "Nerd icon for enum consult source."
  :group 'apex-consult
  :type '(choice string null))

;; Salesforce consult integration (requires salesforce-minor-mode)
(when (featurep 'salesforce-core)
  (salesforce-consult--define-source "apex" :name "Field"
    :narrow ?p
    :category 'Field
    :face 'font-lock-variable-name-face
    :action salesforce-consult--imenu-action
    :state salesforce-consult--imenu-state
    :annotate salesforce-consult--imenu-annotate
    :items
    (lambda ()
      (salesforce-consult--search-candidates "p" "\\`field_declaration\\'" apex-consult-icon-field nil #'apex-ts-mode--variable-name)))

  (salesforce-consult--define-source "apex" :name "Method"
    :narrow ?f
    :category 'Method
    :face 'font-lock-function-name-face
    :action salesforce-consult--imenu-action
    :state salesforce-consult--imenu-state
    :annotate salesforce-consult--imenu-annotate
    :items
    (lambda ()
      (salesforce-consult--search-candidates "f" "\\`method_declaration\\'" apex-consult-icon-method nil #'apex-ts-mode--method-name)))

  (salesforce-consult--define-source "apex" :name "Class"
    :narrow ?c
    :category 'Class
    :face 'font-lock-type-face
    :action salesforce-consult--imenu-action
    :state salesforce-consult--imenu-state
    :annotate salesforce-consult--imenu-annotate
    :items
    (lambda ()
      (salesforce-consult--search-candidates "c" "\\`class_declaration\\'" apex-consult-icon-class nil #'apex-ts-mode--declaration-name)))

  (salesforce-consult--define-source "apex" :name "Sobject"
    :narrow ?s
    :category 'SObject
    :face 'font-lock-type-face
    :action salesforce-consult--imenu-action
    :state salesforce-consult--imenu-state
    :annotate salesforce-consult--imenu-annotate
    :items
    (lambda ()
      (salesforce-consult--search-candidates "o" "\\`storage_identifier\\'" apex-consult-icon-sobject nil #'(lambda (NODE)
                                                                                                              (treesit-node-text NODE)))))

  (salesforce-consult--define-source "apex" :name "Enum"
    :narrow ?e
    :category 'Enum
    :face 'font-lock-constant-face
    :action salesforce-consult--imenu-action
    :state salesforce-consult--imenu-state
    :annotate salesforce-consult--imenu-annotate
    :items
    (lambda ()
      (salesforce-consult--search-candidates "c" "\\`enum_declaration\\'" apex-consult-icon-field nil #'apex-ts-mode--enum-name)))

  (salesforce-consult-make-multi-imenu "apex"
                                       apex--consult-field-source
                                       apex--consult-method-source
                                       apex--consult-class-source
                                       apex--consult-sobject-source
                                       apex--consult-enum-source))

(provide 'apex-consult)

;;; apex-consult.el ends here
