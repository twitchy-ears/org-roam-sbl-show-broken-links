;;; org-roam-show-broken-links.el --- a basic broken/empty link scanner for org-roam, checks file: and roam: links

;; Copyright 2020 - Twitchy Ears

;; Author: Twitchy Ears https://github.com/twitchy-ears/
;; URL: https://github.com/twitchy-ears/org-roam-sbl-show-broken-links
;; Version: 0.1
;; Package-Requires ((emacs "25") (org-roam "1.2.1"))
;; Keywords: org-roam

;; This file is not part of GNU Emacs.

;; This program is free software; you can redistribute it and/or
;; modify it under the terms of the GNU General Public License as
;; published by the Free Software Foundation; either version 3, or
;; (at your option) any later version.
;;
;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
;; General Public License for more details.
;;
;; You should have received a copy of the GNU General Public License
;; along with this program; see the file COPYING.  If not, write to
;; the Free Software Foundation, Inc., 51 Franklin Street, Fifth
;; Floor, Boston, MA 02110-1301, USA.

;;; History
;;
;; 2020-10-09 - initial version

;;; Commentary:
;;
;; To install use something like this:
;; (use-package org-roam-sbl-show-broken-links
;;   :after org-roam
;;   :bind (:map org-roam-mode-map
;;               (("C-c n b" . org-roam-sbl-show-broken-links)
;;                ("C-c n B" . org-roam-sbl-show-all-broken-links))))
;;
;; Then either call org-roam-sbl-show-all-broken-links directory or
;; hit the keybinding.
;;
;; For org-roam-sbl-show-broken-links will run through all the links
;; in the currentbuffer, whereas org-roam-sbl-show-all-broken-links
;; will run through all links in the database - and hence won't scan
;; things that haven't made it to the DB yet.
;;
;; Both will check for roam: and file: links.  file: links are checked
;; for existance on disk, roam: links are checked for existence in the
;; database.  Both are then checked to see if they are "conceptually
;; empty" i.e. they only contain headers and whitespace because
;; they've been immediately inserted - those are also counted as
;; broken because they don't contain any data yet beyond meta-data.

(require 'cl)

(defvar org-roam-sbl-buffername "*org-roam-show-broken-links*"
  "Buffer where output will go, will be overwritten regularly")

(defvar org-roam-sbl-db--check-link-validity-functions
  '(("file" . 'org-roam-sbl--check-file-type-validity)
    ("roam" . 'org-roam-sbl--check-roam-type-validity))
"Takes an alist of functions used to check the validity of various
types of link by org-roam-sbl-db--check-link-validity-p to
extend that easily.  If the function returns t the link is seen
as valid, if it returns nil its seen as invalid.

For example to mark all file: links as invalid use:

(defun my/filechecker (path) nil)
(setq org-roam-sbl-db--check-link-validity-functions 
  '((\"file\" . 'my/filechecker)))")

(defun org-roam-sbl-db--valid-title (checktitle)
  "Returns either a string which should match the input or nil if it
can't find it"
  (let ((data (org-roam-db-query `[:select [titles:title] :from titles :where (= title ,(format "%s" checktitle))])))
    (if data
        (caar data)
      nil)))

(defun org-roam-sbl-db--get-file-from-title (checktitle)
  "Returns a string of the filename associated with that title or nil
if it can't be found"
  (let ((data (org-roam-db-query `[:select [file] :from titles :where (= title ,checktitle)])))
    (if data
        (caar data)
      nil)))

(defun org-roam-sbl-conceptually-blank-file-p (filename)
  "Takes a filename and returns a t if this file contains nothing by
header lines (^#) followed by lines that are either whitespace or
empty. Returns nil if it finds a line with something which isn't a
space.

Also returns t on non-existant files because they are very empty."
  (let* ((canonpath (expand-file-name filename)))
    (if (file-exists-p canonpath)
        (with-temp-buffer
          (insert-file-contents-literally canonpath)
          (goto-char (point-min))
          
          ;; Skip header
          (re-search-forward "^[^#]" nil t)
          
          ;; Look for a non-blank
          (if (re-search-forward "[^[:space:]]" nil t)
              nil ;; Found something so file not empty
            t))   ;; Failed to find something so file conceptually empty
      t))) ;; File doesn't exist so very empty?

(defun org-roam-sbl--check-file-type-validity (link)
  "Takes a filename, checks it exists and that it has some content,
returns true in this case, otherwise nil"
  (if (and (file-exists-p (expand-file-name link))
           (not (org-roam-sbl-conceptually-blank-file-p link)))
      t))

(defun org-roam-sbl--check-roam-type-validity (link)
  "Takes a node title, checks it exists in the DB, directs back to a
file that exists, and that it has some content, returns true in this
case, otherwise nil"
  (let ((maybetitle (org-roam-sbl-db--valid-title link)))
    (if (and maybetitle
             (not (org-roam-sbl-conceptually-blank-file-p
                   (org-roam-sbl-db--get-file-from-title maybetitle))))
        t)))
  
(defun org-roam-sbl-db--check-link-validity-p (link type)
  "Takes a link and a type then attempts to work out if its valid or
not, only works for roam: and file: types in the default
configuration, returns t for every other type because its not in a
position to understand them.

Default configuration calls functions that use
org-roam-conceptually-blank-file-p to check to see if a link has been
inserted immediately but has no content (i.e. is just ^# headers and
whitespace.

Honestly this feels like something there is a function for already
that I'm missing, I had a scan through org-roam.el but I'll probably
find it later.  Probably the most flexible way is to call
org-open-at-point in a funky way and seeing if that can understand the
link in question but I've not looked at that yet.

The functions that are run can be customised by setting the
org-roam-sbl-db--check-link-validity-functions variable."
  (let ((func (elt
               (assoc type org-roam-sbl-db--check-link-validity-functions)
               2)))

    ;; If we have a supplied function then call it with the link in
    ;; question
    (if (and func
             (fboundp func))
        (funcall func link)

      ;; Otherwise assume unknown links are true and valid.
      t)))

(defun org-roam-sbl-show-all-broken-links ()
  "Wrapper function for easy binding, runs:
(org-roam-show-broken-links t) 
so it scans everything not just the current buffer"
  (interactive)
  (org-roam-sbl-show-broken-links t))

(defun org-roam-sbl-show-broken-links (&optional all)
  "Uses org-roam-sbl-scan-for-broken-links to find/check links.  This
function takes the data from that and displays a buffer of each node
and the missing links therein as [[type:link]] for example
[[file:foo.org]] so they can be located and fixed easily."
  (interactive)
  (let* ((data (org-roam-sbl-scan-for-broken-links all))
         (keys)
         (buffername org-roam-sbl-buffername))
    ;; (message "Debug data '%s'" data)
    (save-current-buffer
      (get-buffer-create buffername)
      (with-current-buffer buffername
        (erase-buffer)
        (dolist (dat data keys)
          (add-to-list 'keys (car dat)))
        (dolist (key (sort keys 'cl-equalp))
          (let ((title (org-roam-db--get-titles key)))
            (progn
              (insert (format "Node: [[%s][%s]]\n" key title))

              ;; FIXME: Extract all the relevant rows, yes this is
              ;; very very inefficient and realistically I should be
              ;; already structuring this stuff by node I found it in
              ;; and building a hash of hashes of broken links but I'm
              ;; not.
              (dolist (dat data)
                (if (cl-equalp (car dat) key)
                    (insert (format "[[%s:%s]]\n"
                                    (elt dat 2)
                                    (elt dat 1)))))
              (insert (format "\n")))))
        (goto-char (point-min))
        (org-mode))
      (display-buffer buffername '(display-buffer-at-bottom . nil)))))

(defun org-roam-sbl-scan-for-broken-links (&optional all)
  "Looks through nodes for links of type 'roam' and 'file' and returns
a list of those links that don't appear to actually work.  The list
is in the form: 

((from-node link-target link-type) (from-node link-target link-type) ...)

link-target filenames will attempt to be normalised to absolute paths
if they start with a . to avoid relative links from a node making no
sense to anything using this data.

Will scan the current buffer using (org-roam--extract-links) unless
the all argument is true in which case it will scan the database.
Should probably try and use (org-roam-unlinked-references) or the
logic therein but this seems to mostly work."
  (let* ((rows (if all
                   
                   ;; Extract everything from the database
                   (org-roam-db-query [:select [from to type]
                                               :from links])
                 
                 ;; Otherwise just pull from the current buffer.
                 (org-roam--extract-links)))
         
         (missing)                               ;; Accumulate the results
         (cache (make-hash-table :test 'equal))) ;; Cache link checks
    
    (dolist (row rows missing)
      (let* ((fromlink (elt row 0))
             (tolink (elt row 1))
             (linktype (elt row 2))
             (cached-linkdata (gethash (format "%s:%s" linktype tolink) cache)))
        ;; (message "Starting run, cache: %s" cache)
             
        ;; Check the cache first, if it exists and is 'broken then add
        ;; early
        (if (and cached-linkdata
                 (cl-equalp cached-linkdata 'valid))

            (progn
              ;; (message "From cache %s:%s is valid ignoring" linktype tolink)
              t) ;; its fine, don't reassess

          
          ;; Otherwise actually check it
          
          ;; If we see relative links then they need to be expanded
          ;; out because if the user is viewing *all* broken links and
          ;; has subdirectories then by the time this displays the
          ;; user won't be in the context of the node in question, so
          ;; they'll be faced with ../../foobar.org and following that
          ;; will take them to the wrong place.
          ;;
          ;; FIXME: fixed-path shows up as void?  Probably because we
          ;; try to expand-file-name on invalid files, check this.
          (let ((fixed-path (if (and (cl-equalp linktype "file")
                                     (string-match "^\\." tolink))
                                (expand-file-name tolink (file-name-directory fromlink))
                              tolink)))
            
            
            ;; If its cached as bad then add it to the list as a bad
            ;; link for this source-node
            (if  (and cached-linkdata
                      (cl-equalp cached-linkdata 'invalid))

                (progn
                  ;; (message "From cache adding to missing %s" (list fromlink fixed-path linktype))
                  (add-to-list 'missing (list fromlink fixed-path linktype)))

              ;; Otherwise This is the first time we've seen it
              ;; probably so actually check it.
              ;;
              ;; Spoilers: this is what does all the real work
              (if (not (org-roam-sbl-db--check-link-validity-p tolink linktype))
                  
                    ;; Cache and add to results list
                  (progn
                    ;; (message "Caching %s:%s as invalid, adding to missing" linktype tolink)
                    (puthash (format "%s:%s" linktype tolink) 'invalid cache)
                    (add-to-list 'missing (list fromlink fixed-path linktype)))

                ;; And if that test didn't fail then cache it as a
                ;; valid link so we don't check again
                (progn
                  ;; (message "Caching %s:%s as valid" linktype tolink)
                  (puthash (format "%s:%s" linktype tolink) 'valid cache))))))))))

(provide 'org-roam-sbl-show-broken-links)
