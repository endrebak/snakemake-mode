;;; snakemake-test.el --- Test snakemake{,-mode}.el

;; Copyright (C) 2015-2016 Kyle Meyer <kyle@kyleam.com>

;; Author:  Kyle Meyer <kyle@kyleam.com>

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <http://www.gnu.org/licenses/>.

;;; Code:

(require 'cl-lib)
(require 'snakemake-mode)
(require 'snakemake)
(require 'ert)

;; This is modified from `org-tests.el' (55c0708).
(defmacro snakemake-with-temp-text (text &rest body)
  "Run body in a temporary Snakemake mode buffer.

Fill the buffer with TEXT.  If the string \"<point>\" appears in
TEXT then remove it and place the point there before running
BODY, otherwise place the point at the beginning of the inserted
text.

Also, mute messages."
  (declare (indent 1))
  `(cl-letf (((symbol-function 'message) (lambda (&rest args) nil)))
     (let ((inside-text (if (stringp ,text) ,text (eval ,text))))
       (with-temp-buffer
         (snakemake-mode)
         (let ((point (string-match "<point>" inside-text)))
           (if point
               (progn
                 (insert (replace-match "" nil nil inside-text))
                 (goto-char (1+ (match-beginning 0))))
             (insert inside-text)
             (goto-char (point-min))))
         ,@body))))
(def-edebug-spec snakemake-with-temp-text (form body))

(defmacro snakemake-with-temp-dir (&rest body)
  "Run BODY in a temporary directory with Snakefile.
`snakemake-test-dir' is bound to top-level directory."
  (declare (indent 0) (debug t))
  `(cl-letf (((symbol-function 'message) (lambda (&rest args) nil)))
     (let* ((snakemake-test-dir (file-name-as-directory
                                 (make-temp-file "sm-test-dir" t)))
            (snakemake-root-dir-function `(lambda () ,snakemake-test-dir)))
       (unwind-protect
           (let ((default-directory snakemake-test-dir))
             (mkdir "subdir")
             (with-temp-file "Snakefile"
               (insert "\

rule aa:
    output: \"aa.out\"
    shell: \"echo aa.content > {output}\"

rule bb:
    input: \"aa.out\"
    output: \"bb.out\"
    shell: \"cat {input} > {output}\"

rule cc_wildcards:
    input: \"bb.out\"
    output: \"{name}.outwc\"
    shell: \"cat {input} > {output}\"

rule dd_subdir:
    input: \"aa.out\"
    output: \"subdir/dd.out\"
    shell: \"cat {input} > {output}\""))
             ,@body)
         (delete-directory snakemake-test-dir t)))))
(def-edebug-spec snakemake-with-temp-dir (body))


;;; snakemake-mode.el

;;;; Indentation

(ert-deftest snakemake-test-indent-line/at-rule-block ()
  ;; Always shift first line of block to column 0.
  (should
   (string=
    "rule abc:"
    (snakemake-with-temp-text
        "rule abc:"
      (snakemake-indent-line)
      (buffer-string))))
  (should
   (string=
    "rule abc:"
    (snakemake-with-temp-text
        "     rule abc:"
      (snakemake-indent-line)
      (buffer-string))))

  ;; Don't move point if beyond column 0.
  (should
   (string=
    "rule abc:  "
    (snakemake-with-temp-text
        "    rule abc:  <point>"
      (snakemake-indent-line)
      (buffer-string))))
  (should
   (string=
    "rule "
    (snakemake-with-temp-text
        "    rule <point>abc:  <point>"
      (snakemake-indent-line)
      (buffer-substring (point-min) (point))))))

(ert-deftest snakemake-test-indent-line/outside-rule ()
  ;; Use standard Python mode indentation outside of rule blocks.
  (should
   (string=
    "
def ok():
    "
    (snakemake-with-temp-text
        "
def ok():
<point>"
      (snakemake-indent-line)
      (buffer-string)))))

(ert-deftest snakemake-test-indent-line/field-key ()
  ;; Always indent first line to `snakemake-indent-field-offset'.
  ;; Move point to `snakemake-indent-field-offset' if it is before any
  ;; text on the line.
  (should
   (string=
    "
rule abc:
    "
    (snakemake-with-temp-text
        "
rule abc:
<point>"
      (snakemake-indent-line)
      (buffer-string))))
  (should
   (string=
    "
rule abc:
    "
    (snakemake-with-temp-text
        "
rule abc:
<point>"
      (snakemake-indent-line)
      (snakemake-indent-line)
      (buffer-string))))
  (should
   (string=
    "
rule abc:
    text"
    (snakemake-with-temp-text
        "
rule abc:
text<point>"
      (snakemake-indent-line)
      (buffer-substring (point-min) (point)))))
  (should
   (string=
    "
rule abc:
    te"
    (snakemake-with-temp-text
        "
rule abc:
te<point>xt"
      (snakemake-indent-line)
      (buffer-substring (point-min) (point)))))

  ;; Always indent field key to `snakemake-indent-field-offset'.
  ;; Move point to `snakemake-indent-field-offset' if it is before any
  ;; text on the line.
  (should
   (string=
    "
rule abc:
    input: 'infile'
    output:"
    (snakemake-with-temp-text
        "
rule abc:
    input: 'infile'
<point>output:"
      (snakemake-indent-line)
      (buffer-string))))
  (should
   (string=
    "
rule abc:
    input: 'infile'
    output:"
    (snakemake-with-temp-text
        "
rule abc:
    input: 'infile'
<point>output:"
      (snakemake-indent-line)
      (snakemake-indent-line)
      (buffer-string))))
  (should
   (string=
    "
rule abc:
    input: 'infile'
    output:  "
    (snakemake-with-temp-text
        "
rule abc:
    input: 'infile'
output:  <point>"
      (snakemake-indent-line)
      (buffer-string))))
  (should
   (string=
    "
rule abc:
    input: 'infile'
    "
    (snakemake-with-temp-text
        "
rule abc:
    input: 'infile'
<point>  output:"
      (snakemake-indent-line)
      (buffer-substring (point-min) (point))))))

(ert-deftest snakemake-test-indent-line/field-value ()
  ;; Always indent line below naked field key to
  ;; `snakemake-indent-field-offset' +
  ;; `snakemake-indent-value-offset'.  Move point to to this position
  ;; as well if it is before any text on the line.
  (should
   (string=
    "
rule abc:
    output:
        "
    (snakemake-with-temp-text
        "
rule abc:
    output:
<point>"
      (snakemake-indent-line)
      (buffer-string))))
  (should
   (string=
    "
rule abc:
    output:
        "
    (snakemake-with-temp-text
        "
rule abc:
    output:
<point>"
      (snakemake-indent-line)
      (snakemake-indent-line)
      (buffer-string))))
  (should
   (string=
    "
rule abc:
    output:
        "
    (snakemake-with-temp-text
        "
rule abc:
    output:
              <point>"
      (snakemake-indent-line)
      (buffer-string))))

  ;; Add step with Python indentation for non-blank lines under naked
  ;; field keys.  Field keys with values starting on the same line do
  ;; not use Python indentation because this is invalid syntax in
  ;; Snakemake.
  (should
   (string=
    "
rule abc:
    output: 'file{}{}'.format('one',
    'two'"
    (snakemake-with-temp-text
        "
rule abc:
    output: 'file{}{}'.format('one',
<point>'two'"
      (snakemake-indent-line)
      (buffer-string))))
  (should
   (string=
    "
rule abc:
    output:
        'file{}{}'.format('one',
                          'two'"
    (snakemake-with-temp-text
        "
rule abc:
    output:
        'file{}{}'.format('one',
<point>'two'"
      (snakemake-indent-line)
      (buffer-string))))
  (should
   (string=
    "
rule abc:
    output:
        'file{}{}'.format('one',
    "
    (snakemake-with-temp-text
        "
rule abc:
    output:
        'file{}{}'.format('one',
<point>"
      (snakemake-indent-line)
      (buffer-string))))

  ;; On non-naked field key cycle indentation between
  ;; `snakemake-indent-field-offset' and column of previous field
  ;; value.  If point is before any text on the line, move it to the
  ;; start of the text instead.
  (should
   (string=
    "
rule abc:
    output: 'file'
    "
    (snakemake-with-temp-text
        "
rule abc:
    output: 'file'
<point>"
      (snakemake-indent-line)
      (buffer-string))))
  (should
   (string=
    "
rule abc:
    output: 'file'
            "
    (snakemake-with-temp-text
        "
rule abc:
    output: 'file'
<point>"
      (snakemake-indent-line)
      (snakemake-indent-line)
      (buffer-string))))
  (should
   (string=
    "
rule abc:
    output: 'file'
    "
    (snakemake-with-temp-text
        "
rule abc:
    output: 'file'
<point>"
      (snakemake-indent-line)
      (snakemake-indent-line)
      (snakemake-indent-line)
      (buffer-string))))
  (should
   (string=
    "
rule abc:
    output: 'file'
    'text'"
    (snakemake-with-temp-text
        "
rule abc:
    output: 'file'
<point>'text'"
      (snakemake-indent-line)
      (buffer-string))))
  (should
   (string=
    "
rule abc:
    output: 'file'
            'text'"
    (snakemake-with-temp-text
        "
rule abc:
    output: 'file'
<point>'text'"
      (snakemake-indent-line)
      (snakemake-indent-line)
      (buffer-string))))
  (should
   (string=
    "
rule abc:
    output: 'file'
    'text' "
    (snakemake-with-temp-text
        "
rule abc:
    output: 'file'
'text' <point>"
      (snakemake-indent-line)
      (buffer-string))))
  (should
   (string=
    "
rule abc:
    output: 'file'
  "
    (snakemake-with-temp-text
        "
rule abc:
    output: 'file'
<point>  'text'"
      (snakemake-indent-line)
      (buffer-substring (point-min) (point)))))
  (should
   (string=
    "
rule abc:
    output: 'file'
    'text'"
    (snakemake-with-temp-text
        "
rule abc:
    output: 'file'
<point>  'text'"
      (snakemake-indent-line)
      (snakemake-indent-line)
      (buffer-string))))

  ;; Indent body of run field according to Python mode.
  (should
   (string=
    "
rule abc:
    run:
        with this:
            "
    (snakemake-with-temp-text
        "
rule abc:
    run:
        with this:
<point>"
      (snakemake-indent-line)
      (buffer-string)))))

(ert-deftest snakemake-test/indent-region ()
  (should
   (string=
    "
rule abc:
    input: 'infile'
    output:"
    (snakemake-with-temp-text
        "
<point>rule abc:
input: 'infile'
output:"
      (indent-region (point) (point-max))
      (buffer-string))))
  (should
   (string=
    "
rule abc:
    input:
        one='one', two='two'
    output: 'out'
    run:
        with open(input.one) as ifh:
            with open(output.out, 'w') as ofh:
                ofh.write(ifh.read())"
    (snakemake-with-temp-text
        "
<point>rule abc:
input:
one='one', two='two'
output: 'out'
run:
with open(input.one) as ifh:
with open(output.out, 'w') as ofh:
ofh.write(ifh.read())"
      (indent-region (point) (point-max))
      (buffer-string))))
  (should
   (string=
    "
x = [1,
     2,
     3,]"
    (snakemake-with-temp-text
     "
<point>x = [1,
2,
3,]"
     (indent-region (point) (point-max))
     (buffer-string)))))

;;;; Other

(ert-deftest snakemake-test-in-rule-or-subworkflow-block-p ()
  ;; At top of block
  (snakemake-with-temp-text
      "
<point>rule abc:
    output: 'file'"
    (should (snakemake-in-rule-or-subworkflow-block-p)))

  ;; Body of block
  (snakemake-with-temp-text
      "
rule abc:
    output: <point>'file'"
    (should (snakemake-in-rule-or-subworkflow-block-p)))

  ;; First blank line after
  (snakemake-with-temp-text
      "
rule abc:
    output: 'file'
<point>"
    (should (snakemake-in-rule-or-subworkflow-block-p)))

  ;; Second blank line after
  (snakemake-with-temp-text
      "
rule abc:
    output: 'file'

<point>"
    (should-not (snakemake-in-rule-or-subworkflow-block-p)))


  ;; Blank line in docstring
  (snakemake-with-temp-text
      "
rule abc:
     \"\"\"docstring header

     docstring line
     \"\"\"
    output: 'file'<point>"
    (should (snakemake-in-rule-or-subworkflow-block-p)))

  ;; Before
  (snakemake-with-temp-text
      "<point>
rule abc:
    output: 'file'"
    (should-not (snakemake-in-rule-or-subworkflow-block-p)))

  ;; At beginning of buffer
  (snakemake-with-temp-text
      "\
rule abc:
    output: 'file'<point>"
    (should (snakemake-in-rule-or-subworkflow-block-p)))

  ;; Subworkflow
  (snakemake-with-temp-text
      "
subworkflow otherworkflow:
<point>    workdir: '../path/to/otherworkflow'
    snakefile: '../path/to/otherworkflow/Snakefile'"
    (should (snakemake-in-rule-or-subworkflow-block-p))))

(ert-deftest snakemake-test-first-field-line-p ()
  (snakemake-with-temp-text
      "
rule abc:
<point>"
    (should (snakemake-first-field-line-p)))
  (snakemake-with-temp-text
      "
rule abc:
<point>    output: 'file'"
    (should (snakemake-first-field-line-p)))
  (snakemake-with-temp-text
      "
rule abc:
    output:
<point>"
    (should-not (snakemake-first-field-line-p))))

(ert-deftest snakemake-test-below-naked-field-p ()
  (snakemake-with-temp-text
      "
rule abc:
    output:
<point>"
    (should (snakemake-below-naked-field-p)))
  (snakemake-with-temp-text
      "
rule abc:
    output: 'file'
<point>"
    (should-not (snakemake-below-naked-field-p)))
  (snakemake-with-temp-text
      "
rule abc:
    output: <point>"
    (should-not (snakemake-below-naked-field-p))))

(ert-deftest snakemake-test-naked-field-line-p ()
  (snakemake-with-temp-text
      "
rule abc:
    output:
<point>"
    (should (snakemake-naked-field-line-p)))
  (snakemake-with-temp-text
      "
rule abc:
    output:
        'file',
         <point>"
    (should (snakemake-naked-field-line-p)))
  (snakemake-with-temp-text
      "
rule abc:
    output: <point>"
    (should (snakemake-naked-field-line-p)))
  (snakemake-with-temp-text
      "
rule abc:
    output: 'file'
<point>"
    (should-not (snakemake-naked-field-line-p)))
  (snakemake-with-temp-text
      "
rule abc:
    input:
        'infile'
    output: 'file'
<point>"
    (should-not (snakemake-naked-field-line-p))))

(ert-deftest snakemake-test-run-field-line-p ()
  (snakemake-with-temp-text
      "
rule abc:
    run:
<point>"
    (should (snakemake-run-field-line-p)))
  (snakemake-with-temp-text
      "
rule abc:
    run:
        with file:
<point>"
    (should (snakemake-run-field-line-p)))
  (snakemake-with-temp-text
      "
rule abc:
    output: 'file'
<point>"
    (should-not (snakemake-run-field-line-p))))

(ert-deftest snakemake-test-previous-field-value-column ()
  (should (= 12
             (snakemake-with-temp-text
                 "
rule abc:
    output: 'file'
<point>"
               (snakemake-previous-field-value-column))))
  (should (= 12
             (snakemake-with-temp-text
                 "
rule abc:
    output: 'file',
            'another'
<point>"
               (snakemake-previous-field-value-column)))))


;;; snakemake.el

(ert-deftest snakemake-test-snakefile-directory ()
  (snakemake-with-temp-dir
    (should (equal default-directory (snakemake-snakefile-directory)))
    (let ((topdir default-directory))
      (should (equal topdir
                     (let ((default-directory "subdir"))
                       (snakemake-snakefile-directory)))))))

(ert-deftest snakemake-test-rule-targets ()
  (should
   (equal '("aa" "bb" "dd_subdir")
          (snakemake-with-temp-dir
            (snakemake-rule-targets)))))

(ert-deftest snakemake-test-all-rules ()
  (should
   (equal '("aa" "bb" "cc_wildcards" "dd_subdir")
          (snakemake-with-temp-dir
            (snakemake-all-rules)))))

(ert-deftest snakemake-test-file-targets ()
  (should
   (equal
    (and snakemake-file-target-program
         '("aa.out" "bb.out" "subdir/dd.out"))
    (snakemake-with-temp-dir
      (snakemake-file-targets)))))

(ert-deftest snakemake-test-check-target ()
  (should
   (snakemake-with-temp-dir
     (snakemake-check-target "aa.out")))
  (should-not
   (snakemake-with-temp-dir
     (snakemake-check-target "aa.out.not-target"))))

(ert-deftest snakemake-test-org-link-file-targets ()
  (should (equal '("/path/to/fname")
                 (with-temp-buffer
                   (org-mode)
                   (insert "\n[[file:/path/to/fname][descr]]\n")
                   (forward-line -1)
                   (snakemake-org-link-file-targets)))))

(ert-deftest snakemake-test-region-file-targets ()
  (let ((files '("/path/to/fname" "fname2" "CAP")))
    (should (equal (mapcar #'expand-file-name files)
                   (with-temp-buffer
                     (insert (mapconcat #'identity files "\n"))
                     (snakemake-region-file-targets
                      (point-min) (point-max)))))
    (should (equal (mapcar #'expand-file-name files)
                   (with-temp-buffer
                     (insert (mapconcat #'identity files ","))
                     (snakemake-region-file-targets
                      (point-min) (point-max)))))
    (should (equal (mapcar #'expand-file-name files)
                   (with-temp-buffer
                     (insert (car files))
                     (insert ?\n)
                     (insert (mapconcat #'identity (cdr files) " "))
                     (snakemake-region-file-targets
                      (point-min) (point-max)))))))

(ert-deftest snakemake-test-file-targets-at-point ()
  (should
   (equal '("aa.out")
          (snakemake-with-temp-dir
            (with-temp-buffer
              (insert "aa.out")
              (beginning-of-line)
              (snakemake-file-targets-at-point 'check)))))
  (should-not
   (snakemake-with-temp-dir
     (with-temp-buffer
       (insert "aa.out.not-target")
       (beginning-of-line)
       (snakemake-file-targets-at-point 'check))))
  (should
   (equal '("aa.out.not-target")
          (snakemake-with-temp-dir
            (with-temp-buffer
              (insert "aa.out.not-target")
              (beginning-of-line)
              (snakemake-file-targets-at-point))))))

(ert-deftest snakemake-test-rule-at-point ()
  (should
   (equal '("aa")
          (snakemake-with-temp-dir
            (with-temp-buffer
              (snakemake-mode)
              (insert-file-contents "Snakefile")
              (re-search-forward "rule aa:")
              (snakemake-rule-at-point 'target)))))
  (should
   (equal '("cc_wildcards")
          (snakemake-with-temp-dir
            (with-temp-buffer
              (snakemake-mode)
              (insert-file-contents "Snakefile")
              (re-search-forward "rule cc_wildcards:")
              (snakemake-rule-at-point)))))
  (should-not
   (snakemake-with-temp-dir
    (with-temp-buffer
      (snakemake-mode)
      (insert-file-contents "Snakefile")
      (re-search-forward "rule cc_wildcards:")
      (snakemake-rule-at-point 'target)))))

(provide 'snakemake-test)
;;; snakemake-test.el ends here
