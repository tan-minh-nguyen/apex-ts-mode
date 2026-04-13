;;; apex-combobulate.el --- Combobulate support for Apex -*- lexical-binding: t -*-

;; Copyright (C) 2026 Tan Nguyen

;; Author: Tan Nguyen <tan.nguyen.w.information@gmail.com>
;; Version: 1.0.0
;; Package-Requires: ((emacs "29.1") (apex-ts-mode "1.0") (combobulate "0.1"))
;; Keywords: languages, apex, salesforce, tree-sitter
;; URL: https://github.com/tan-minh-nguyen/apex-ts-mode

;; This file is part of apex-ts-mode extensions.

;; SPDX-License-Identifier: GPL-3.0-or-later

;;; Commentary:

;; This package provides Combobulate integration for Apex mode,
;; enabling structured editing and navigation through Apex code.
;;
;; Usage:
;;   (with-eval-after-load 'combobulate
;;     (require 'apex-combobulate))
;;   (add-hook 'apex-ts-mode-hook #'combobulate-mode)

;;; Code:

(require 'combobulate-settings)
(require 'combobulate-navigation)
(require 'combobulate-manipulation)
(require 'combobulate-interface)
(require 'combobulate-rules)
(require 'combobulate-setup)

(defgroup apex-combobulate nil
  "Combobulate integration for Apex mode."
  :group 'apex
  :prefix "apex-combobulate-")

(defun combobulate-apex-pretty-print-node-name (node default-name)
  "Pretty print NODE name for Apex.
Returns a formatted string or DEFAULT-NAME if no special formatting applies."
  (combobulate-string-truncate
   (replace-regexp-in-string
    (rx (| (>= 2 " ") "\n")) ""
    (pcase (combobulate-node-type node)
      ("method_declaration"
       (concat "method "
               (combobulate-node-text
                (combobulate-node-child-by-field node "name"))))
      ("class_declaration"
       (concat "class "
               (combobulate-node-text
                (combobulate-node-child-by-field node "name"))))
      ("interface_declaration"
       (concat "interface "
               (combobulate-node-text
                (combobulate-node-child-by-field node "name"))))
      ("enum_declaration"
       (concat "enum "
               (combobulate-node-text
                (combobulate-node-child-by-field node "name"))))
      ("constructor_declaration"
       (concat "constructor "
               (combobulate-node-text
                (combobulate-node-child-by-field node "name"))))
      ("field_declaration"
       (combobulate-node-text
        (combobulate-node-child-by-field node "declarator")))
      ("identifier" (combobulate-node-text node))
      (_ default-name)))
   40))

(defvar combobulate-apex-definitions
  '((context-nodes
     '("identifier" "type_identifier" "boolean" "null_literal"
       "int" "decimal_floating_point_literal" "string_literal"
       "this" "super"))

    (pretty-print-node-name-function #'combobulate-apex-pretty-print-node-name)

    (indent-after-edit t)
    (envelope-indent-region-function #'indent-region)

    ;; Defun navigation - methods, classes, interfaces
    (procedures-defun
     '((:activation-nodes
        ((:nodes ("method_declaration" "class_declaration"
                  "interface_declaration" "enum_declaration"
                  "constructor_declaration"))))))

    ;; Sibling navigation - traverse statements and parameters
    (procedures-sibling
     `(;; Navigate between statements in a block
       (:activation-nodes
        ((:nodes ((rule "block") (rule "class_body") (rule "interface_body")
                  (rule "enum_body"))
                 :position at
                 :has-parent ("block" "class_body" "interface_body" "enum_body")))
        :selector (:match-children t))

       ;; Navigate between method/field declarations in class body
       (:activation-nodes
        ((:nodes ("method_declaration" "field_declaration" "constructor_declaration")
                 :has-parent ("class_body" "interface_body")))
        :selector (:match-children t))

       ;; Navigate between formal parameters
       (:activation-nodes
        ((:nodes ((rule "formal_parameters"))
                 :has-parent ("formal_parameters")))
        :selector (:match-children t))

       ;; Navigate between arguments in method calls
       (:activation-nodes
        ((:nodes ((rule "argument_list"))
                 :has-parent ("argument_list")))
        :selector (:match-children t))

       ;; Navigate between switch cases
       (:activation-nodes
        ((:nodes ("switch_label")
                 :has-parent ("switch_block")))
        :selector (:match-children (:match-rules ("switch_label"))))

       ;; Navigate in array/map initializers
       (:activation-nodes
        ((:nodes ((rule "array_initializer") (rule "map_initializer"))
                 :has-parent ("array_initializer" "map_initializer")))
        :selector (:match-children t))))

    ;; Hierarchy navigation - into/out of blocks
    (procedures-hierarchy
     `(;; Navigate into blocks
       (:activation-nodes
        ((:nodes "block" :position at))
        :selector (:choose node :match-children t))

       ;; Navigate into class/interface body
       (:activation-nodes
        ((:nodes ("class_body" "interface_body" "enum_body") :position at))
        :selector (:choose node :match-children t))

       ;; Navigate into method/class from declaration
       (:activation-nodes
        ((:nodes ("method_declaration" "class_declaration"
                  "interface_declaration" "constructor_declaration")
                 :position at))
        :selector (:choose node :match-children
                           (:match-rules ("block" "class_body" "interface_body"))))

       ;; Navigate into control flow statements
       (:activation-nodes
        ((:nodes ("if_statement" "for_statement" "while_statement"
                  "do_statement" "try_statement" "switch_statement")
                 :position at))
        :selector (:choose node :match-children
                           (:match-rules ("block" "switch_block"))))

       ;; General fallback
       (:activation-nodes
        ((:nodes ((all))))
        :selector (:choose node :match-children t))))

    ;; Sexp navigation
    (procedures-sexp
     '((:activation-nodes
        ((:nodes ("method_declaration" "class_declaration"
                  "interface_declaration" "enum_declaration"
                  "constructor_declaration"
                  "if_statement" "for_statement" "while_statement"
                  "do_statement" "try_statement" "switch_statement"
                  "block" "expression_statement"))))))

    ;; Logical navigation
    (procedures-logical
     '((:activation-nodes ((:nodes (all))))))

    ;; Envelope shorthand procedures
    (envelope-procedure-shorthand-alist
     '((general-statement
        . ((:activation-nodes
            ((:nodes ((rule "block") (rule "_statement")
                      (rule "class_body"))
                     :has-parent ("block" "class_body"))))))))

    ;; Code template envelopes
    (envelope-list
     '(;; Control flow - if statements
       (:description
        "if (...) { ... }"
        :key "i"
        :mark-node t
        :shorthand general-statement
        :name "if-statement"
        :template ("if (" @ ") {" n> r> n> "}" >))

       (:description
        "if (...) { ... } else { ... }"
        :key "I"
        :mark-node t
        :shorthand general-statement
        :name "if-else-statement"
        :template ("if (" @ ") {" n> r> n> "} else {" n> @ n> "}" >))

       (:description
        "if (...) { ... } else if (...) { ... }"
        :key "C-i"
        :mark-node t
        :shorthand general-statement
        :name "if-elseif-statement"
        :template ("if (" @ ") {" n> r> n> "} else if (" @ ") {" n> @ n> "}" >))

       ;; Control flow - loops
       (:description
        "for (Type var : collection) { ... }"
        :key "f"
        :mark-node t
        :shorthand general-statement
        :name "for-each-loop"
        :template ("for (" (p Type "Type") " " (p item "Variable") " : " @ ") {" n> r> n> "}" >))

       (:description
        "for (Integer i = 0; i < n; i++) { ... }"
        :key "F"
        :mark-node t
        :shorthand general-statement
        :name "for-loop"
        :template ("for (Integer " (p i "Iterator") " = 0; " (f i) " < " @ "; " (f i) "++) {" n> r> n> "}" >))

       (:description
        "while (...) { ... }"
        :key "w"
        :mark-node t
        :shorthand general-statement
        :name "while-loop"
        :template ("while (" @ ") {" n> r> n> "}" >))

       (:description
        "do { ... } while (...);"
        :key "W"
        :mark-node t
        :shorthand general-statement
        :name "do-while-loop"
        :template ("do {" n> r> n> "} while (" @ ");" >))

       ;; Exception handling
       (:description
        "try { ... } catch (Exception e) { ... }"
        :key "t"
        :mark-node t
        :shorthand general-statement
        :name "try-catch"
        :template ("try {" n> r> n> "} catch (Exception " (p e "Variable") ") {" n> @ n> "}" >))

       (:description
        "try { ... } catch (Exception e) { ... } finally { ... }"
        :key "T"
        :mark-node t
        :shorthand general-statement
        :name "try-catch-finally"
        :template ("try {" n> r> n> "} catch (Exception " (p e "Variable") ") {" n> @ n> "} finally {" n> @ n> "}" >))

       ;; Method definitions
       (:description
        "public ReturnType methodName() { ... }"
        :key "m"
        :mark-node t
        :shorthand general-statement
        :name "public-method"
        :template ("public " (p void "Return Type") " " (p methodName "Method Name") "(" @ ") {" n> r> n> "}" >))

       (:description
        "private ReturnType methodName() { ... }"
        :key "M"
        :mark-node t
        :shorthand general-statement
        :name "private-method"
        :template ("private " (p void "Return Type") " " (p methodName "Method Name") "(" @ ") {" n> r> n> "}" >))

       (:description
        "public static ReturnType methodName() { ... }"
        :key "S"
        :mark-node t
        :shorthand general-statement
        :name "static-method"
        :template ("public static " (p void "Return Type") " " (p methodName "Method Name") "(" @ ") {" n> r> n> "}" >))

       ;; Debug and testing
       (:description
        "System.debug(...)"
        :key "d"
        :mark-node nil
        :name "debug"
        :template ("System.debug(" @ ");"))

       (:description
        "System.debug(LoggingLevel.DEBUG, ...)"
        :key "D"
        :mark-node nil
        :name "debug-level"
        :template ("System.debug(LoggingLevel." (p DEBUG "Level") ", " @ ");"))

       (:description
        "System.assertEquals(expected, actual)"
        :key "a"
        :mark-node nil
        :name "assert-equals"
        :template ("System.assertEquals(" @ ", " @ ");"))

       (:description
        "System.assertEquals(expected, actual, message)"
        :key "A"
        :mark-node nil
        :name "assert-equals-message"
        :template ("System.assertEquals(" @ ", " @ ", '" @ "');"))

       (:description
        "System.assertNotEquals(expected, actual)"
        :key "n"
        :mark-node nil
        :name "assert-not-equals"
        :template ("System.assertNotEquals(" @ ", " @ ");"))

       ;; Test method
       (:description
        "@isTest static void testMethod() { ... }"
        :key "s"
        :mark-node t
        :shorthand general-statement
        :name "test-method"
        :template ("@isTest" n> "static void " (p testMethod "Test Method Name") "() {" n> r> n> "}" >))

       (:description
        "@testSetup static void setup() { ... }"
        :key "S-s"
        :mark-node t
        :shorthand general-statement
        :name "test-setup"
        :template ("@testSetup" n> "static void setup() {" n> r> n> "}" >))

       ;; SOQL
       (:description
        "[SELECT ... FROM ...]"
        :key "q"
        :mark-node nil
        :name "soql-query"
        :template ("[SELECT " @ " FROM " @ "]"))

       (:description
        "[SELECT ... FROM ... WHERE ...]"
        :key "Q"
        :mark-node nil
        :name "soql-query-where"
        :template ("[SELECT " @ " FROM " @ " WHERE " @ "]"))

       ;; DML
       (:description
        "insert records;"
        :key "C-d i"
        :mark-node nil
        :name "dml-insert"
        :template ("insert " @ ";"))

       (:description
        "update records;"
        :key "C-d u"
        :mark-node nil
        :name "dml-update"
        :template ("update " @ ";"))

       (:description
        "delete records;"
        :key "C-d d"
        :mark-node nil
        :name "dml-delete"
        :template ("delete " @ ";"))))))

;; Register the language with Combobulate
(define-combobulate-language
 :name apex
 :language apex
 :major-modes (apex-ts-mode)
 :custom combobulate-apex-definitions
 :setup-fn combobulate-apex-setup)

(defun combobulate-apex-setup (_)
  "Setup function for Apex Combobulate mode."
  ;; Any Apex-specific setup can go here
  nil)

(provide 'apex-combobulate)
;;; apex-combobulate.el ends here
