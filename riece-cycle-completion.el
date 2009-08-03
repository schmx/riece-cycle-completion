;;;; riece-cycle-completion.el --- Name cycling completion for riece -*- Emacs-Lisp -*-
;;;;
;;;; Copyright (C) 2008 Marcus Eskilsson
;;;;
;;;; Author:     Marcus Eskilsson <marcus@sxemacs.org>
;;;; Maintainer: Marcus Eskilsson <marcus@sxemacs.org>
;;;; Created:    <2008-01-06>
;;;; Homepage:   N/A
;;;; Keywords:   irc riece completion
;;;;
;;;; Redistribution and use in source and binary forms, with or without
;;;; modification, are permitted provided that the following conditions
;;;; are met:
;;;;
;;;; 1. Redistributions of source code must retain the above copyright
;;;;    notice, this list of conditions and the following disclaimer.
;;;;
;;;; 2. Redistributions in binary form must reproduce the above copyright
;;;;    notice, this list of conditions and the following disclaimer in the
;;;;    documentation and/or other materials provided with the distribution.
;;;;
;;;; 3. Neither the name of the author nor the names of any contributors
;;;;    may be used to endorse or promote products derived from this
;;;;    software without specific prior written permission.
;;;;
;;;; THIS SOFTWARE IS PROVIDED BY THE AUTHOR "AS IS" AND ANY EXPRESS OR
;;;; IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
;;;; WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
;;;; DISCLAIMED.  IN NO EVENT SHALL THE REGENTS OR CONTRIBUTORS BE LIABLE
;;;; FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
;;;; CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
;;;; SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR
;;;; BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
;;;; WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE
;;;; OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN
;;;; IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
;;;;
;;;; Commentary:
;;;;
;;;; Cycling nick completion for riece. This is a replacement for riece's default nick
;;;; completion. It matches names in riece-current-channel and lets you cycle through all
;;;; matches by repeatedly calling the function. Preferably the function is mapped to TAB.
;;;;
;;;; The easiest way to enable this is by:
;;;;
;;;; (defalias 'riece-command-complete-user 'riece-cycle:command-cycle-complete-user)
;;;;
;;;; The actual code uses a timer for this magic to work. You will need to do the next call
;;;; to riece-me:command-cycle-complete-user before the time is up or it will be interpreted
;;;; as a new call and a fresh completion list will be created. If you find that you can not
;;;; keep up with the timer, or find it too slow, the variable to set is riece-me:completion-time.
;;;;
;;;; The code is known to work with SXEmacs 22.1.8, and most likely will work just fine in
;;;; XEmacs. It is, however, known to be broken for GNU Emacs.
;;;;

(require 'cl)

(defvar riece-cycle:completion-time 0.7 "Time in seconds before completion list is reset.")
(defvar riece-cycle:*completion-timer* nil "Completion timer.")
(defvar riece-cycle:*completion-list* nil "Completion list.")

(defvar riece-cycle:*riece-completion-syntax-table*
  (let ((table (copy-syntax-table text-mode-syntax-table)))
    (modify-syntax-entry ?~  "w " table)
    (modify-syntax-entry ?`  "w " table)
    (modify-syntax-entry ?-  "w " table)
    (modify-syntax-entry ?_  "w " table)
    (modify-syntax-entry ?+  "w " table)
    (modify-syntax-entry ?{  "w " table)
    (modify-syntax-entry ?[  "w " table)
    (modify-syntax-entry ?}  "w " table)
    (modify-syntax-entry ?]  "w " table)
    (modify-syntax-entry ?\\ "w " table)
    (modify-syntax-entry ?|  "w " table)
    (modify-syntax-entry ?:  "w " table)
    (modify-syntax-entry ?\; "w " table)
    (modify-syntax-entry ?'  "w " table)
    (modify-syntax-entry ?<  "w " table)
    (modify-syntax-entry ?,  "w " table)
    (modify-syntax-entry ?>  "w " table)
    table)
  "Syntax table used in funky nick cycling completion.")

(defun riece-cycle:command-cycle-complete-user ()
  "Cycle completion for riece.
Cycle through matches by repeated calls to this command."
  (interactive)
  (with-syntax-table riece-cycle:*riece-completion-syntax-table*
    (if (null riece-cycle:*completion-list*)
	;; Creates a completion list of matching nicks and stores it for further abuse.
	(let* ((completion-ignore-case t)
	       (table (riece-with-server-buffer
			  (riece-identity-server riece-current-channel)
			(riece-channel-get-users (riece-identity-prefix
						  riece-current-channel))))
	       (current (or (current-word)
			    ""))
	       (completion (try-completion current table))
	       (all (all-completions current table)))
	  (if (null completion)
	      (message "Can't find completion for \"%s\"" current)
	      (setf riece-cycle:*completion-list* all))))
    (if (not (null riece-cycle:*completion-list*))
	(labels ((cycle-list (list)
     		   ;; Returns the head of list and the rotated list.
		   (let ((name (pop list)))
		     (values name (append list (list name)))))
		 (reset-completion-list ()
		   ;; Returns completion-list to nil.
		   (setf riece-cycle:*completion-list* nil))
		 (set-timer ()
		   ;; Cleans up and sets timer for completion timeout.
		   (if (itimerp riece-cycle:*completion-timer*)
		       (delete-itimer riece-cycle:*completion-timer*))
		   (setf riece-cycle:*completion-timer* 
			 (run-at-time riece-cycle:completion-time
				      nil
				      #'reset-completion-list))))
	  (multiple-value-bind (completion newlist)
	      (cycle-list riece-cycle:*completion-list*)
	    ;; Insert first name in list and set timer.
	    (setf riece-cycle:*completion-list* newlist)
	    (if (not (string= "" (current-word)))
		(backward-delete-word))
	    (insert completion)
	    (let ((current-point (point)))
	      ;; #### TODO: Add a save-excursion
	      (backward-word)
	      (if (not (= (point)
			  (point-at-bol)))
		  (progn
		    (goto-char current-point)
		    (insert " ")) ; Not at bol! Let's add a ?\ .
		  (goto-char current-point)
		  (insert ": "))) ; We're at bol! Let's add a ?\:.
	    (set-timer))))))

(provide 'riece-cycle-completion)
