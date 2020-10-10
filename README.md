# org-roam-sbl-show-broken-links

A basic broken/empty link scanner for [org-roam](https://www.orgroam.com/), checks file: and roam: links by default.

To make it work drop it in your load-path somewhere and put something
like this in your config file:

```
(use-package org-roam-sbl-show-broken-links
  :after org-roam
  :bind (:map org-roam-mode-map
              (("C-c n b" . org-roam-sbl-show-broken-links)
               ("C-c n B" . org-roam-sbl-show-all-broken-links))))
```

Then restart emacs and hit "Ctrl+c, n, B" and it'll scan everything in
your org-roam database, its not going to be blazingly fast but it can
scan ~500 files pretty instantly off an SSD so you should see a buffer
pop up with results pretty much immediately.

This is mostly composed of two functions 

1. org-roam-sbl-show-broken-links: calls the scanning function then
   displays the results in a popup buffer

2. org-roam-sbl-scan-for-broken-links: looks at your current buffer or 
   DB and checks the links for a notion of validity

The idea is that calling the first will use the second to actually
examine the default look at your current buffer and extract any file:
or roam: type links from it, check those for validity, and pass the
results back.  The first then displays whatever it gets back.

Each link is checked for validity, and by default only roam: and file:
links are checked.  Roam links are checked that they exist in the
database and that there is a file pointed to by them, file links just
the file is checked.  Both types are then checked for conceptual
emptyness, essentially that they contain more than just ^#+ headers
and whitespace.  This means if you have used org-roam-insert-immediate
or similar it will be detected as broken if you haven't gone back to
fill in any information yet.

You can customise which functions are used to check the validity of
links, and hence which links are checked, by setting the
org-roam-sbl-db--check-link-validity-functions variable.

By default this is:

```
'(("file" . 'org-roam-sbl--check-file-type-validity)
  ("roam" . 'org-roam-sbl--check-roam-type-validity))
```

A simple example of just marking every single file: link as broken and
ignoring every other type of link would be:

```
(defun my/filechecker (path) nil)
(setq org-roam-sbl-db--check-link-validity-functions 
  '(("file" . 'my/filechecker)))
```
