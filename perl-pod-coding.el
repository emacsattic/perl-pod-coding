;;; perl-pod-coding.el --- coding system from =encoding in perl files

;; Copyright 2007 Kevin Ryde
;;
;; Author: Kevin Ryde <user42@zip.com.au>
;; Version: 1
;; Keywords: i18n
;; URL: http://www.geocities.com/user42_kevin/perl-pod-coding/index.html
;; EmacsWiki: PerlLanguage
;;
;; perl-pod-coding.el is free software; you can redistribute it and/or
;; modify it under the terms of the GNU General Public License as published
;; by the Free Software Foundation; either version 3, or (at your option)
;; any later version.
;;
;; perl-pod-coding.el is distributed in the hope that it will be useful, but
;; WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General
;; Public License for more details.
;;
;; You can get a copy of the GNU General Public License online at
;; http://www.gnu.org/licenses.


;;; Commentary:

;; This is a spot of code to get an Emacs coding system from the "=encoding"
;; line in perl pod documentation, either inline in perl code, or a separate
;; pod file.
;;
;; Emacs can often recognise unicode by itself, it can definitely recognise
;; the unicode byte order markers (utf-16 or utf-8) which pod files can use,
;; but other coding systems need some help.

;;; Install:

;; Put perl-pod-coding.el somewhere in your `load-path', and in your .emacs
;; put
;;
;;     (require 'perl-pod-coding)
;;
;; Or if you'd like to put off loading it until your first file visit, then
;; try
;;
;;     (autoload 'perl-pod-coding-function "perl-pod-coding")
;;     (if (boundp 'auto-coding-functions) ;; emacs 22 and up
;;         (add-to-list 'auto-coding-functions 'perl-pod-coding-function)
;;       (require 'perl-pod-coding))
;;
;; There's autoload cookies for this below, if you use
;; `update-file-autoloads' and friends.

;;; Emacsen:

;; Designed for Emacs 21 and 22.  Doesn't work in XEmacs 21.

;;; History:

;; Version 1 - the first version.


;;; Code:

;;;###autoload (if (boundp 'auto-coding-functions) (add-to-list 'auto-coding-functions 'perl-pod-coding-function) (require 'perl-pod-coding))

;;;###autoload
(defun perl-pod-coding-function (size)
  "Return the coding system for perl pod, based on an =encoding line.
At point there should be SIZE many bytes from an
`insert-file-contents-literally' of the first part of a file.  If
there's an =encoding near the start, and the charset it gives is
known, then an Emacs coding system is returned.  If not the
return is nil.

The =encoding must be at the start of the line, preceded and
followed by a blank line (or be at the start or end of the
buffer).  Hopefully this should be tight enough to avoid false
matches.  (When discussing =encoding itself it's likely to be
indented, or be within a paragraph.)

Charset names are recognised with
`locale-charset-to-coding-system' in Emacs 22, and with the
`mm-util' package from Gnus for Emacs 21.  The possible names are
described in the Encode::Supported page, they can be perlish
common names like \"utf8\", or MIME registered names, or IANA
registered names."

  (save-excursion
    (save-restriction
      ;; look only at SIZE being inserted, and only at first 100 lines
      (narrow-to-region (point) (+ (point) size))
      (forward-line 100)
      (narrow-to-region (point-min) (point))
      (goto-char (point-min))

      (and (let ((case-fold-search nil))
             (re-search-forward "\\(\\`\\|\n\\)=encoding \\(.*\\)\\(\\'\\|\n\\(\\'\\|\n\\)\\)"
                                (point-max) t))
           (let ((charset (match-string 2)))

             (or (and (fboundp 'locale-charset-to-coding-system) ;; emacs 22
                      (locale-charset-to-coding-system charset))

                 ;; emacs21
                 (progn
                   (eval-and-compile ;; quieten the byte compiler
                     (require 'mm-util))
                   (let ((coding (mm-charset-to-coding-system charset)))
                     ;; `mm-charset-to-coding-system' returns `ascii'
                     ;; for ascii or us-ascii, but that's not actually a
                     ;; coding system.  Gnus copes with that in various
                     ;; places (usually treating ascii as meaning no
                     ;; conversion), go undecided here.
                     (if (and (eq coding 'ascii)
                              (not (coding-system-p coding)))
                         (setq coding 'undecided))

                     coding))

                 (progn
                   ;; prefer `display-warning' when available, since a plain
                   ;; `message' tends to be overwritten in many cases
                   (if (fboundp 'display-warning) ;; not in emacs 21
                       (display-warning
                        'i18n
                        (format "Unknown POD charset: %s" charset)
                        :warning)
                     (message "Unknown POD charset: %s" charset))
                   nil)))))))

(if (boundp 'auto-coding-functions)
    ;; emacs 22
    ;;
    ;; note no custom-add-option onto auto-coding-functions here, since as
    ;; of emacs 22.1 it only has type "(repeat function)" and adding
    ;; :options to that makes customize-variable throw an error
    ;;
    (add-to-list 'auto-coding-functions 'perl-pod-coding-function)

  ;; emacs 21
  (defadvice set-auto-coding (around perl-pod-coding activate)
    "Find the coding system for reading a perl pod file, based on the =encoding.
See `perl-pod-coding-function' for details."

    (let ((perl-pod-coding-save-point (point)))
      (unless ad-do-it
        (save-excursion
          (goto-char perl-pod-coding-save-point)
          (setq ad-return-value (perl-pod-coding-function size)))))))

(provide 'perl-pod-coding)

;;; perl-pod-coding.el ends here
