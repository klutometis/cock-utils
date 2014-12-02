#!/usr/bin/env chicken-scheme

(use alist-lib
     args
     cock-utils
     data-structures
     files
     miscmacros
     posix
     shell
     usage)

(define options
  (make-parameter
   (list (args:make-option (h ? help) #:none "Help" (set! arg #t))
         (args:make-option (l latex) #:none "Output to LaTeX" (set! arg #t))
         (args:make-option (m meta-file) (required: "METAFILE") "The egg's METAFILE")
         (args:make-option (o output) (required: "FILE") "Output to FILE")
         (args:make-option (r repo) (required: "REPO") "The egg's REPO")
         (args:make-option (p pdf) #:none "Output to PDF" (set! arg #t))
         (args:make-option (w wiki) #:none "Output to wiki [default]" (set! arg #t)))))

(define usage
  (make-usage
   (lambda (program)
     (format #t "Usage: ~a [OPTIONS]... FILE...~%" program)
     (print (args:usage (options))))))

(define (parse-and-write write-docexprs files metafile repo)
  (write-docexprs (apply parse-files files) metafile repo))

(define (option options option)
  (alist-ref/default options option #f))

(receive (options files)
  (args:parse (command-line-arguments) (options))
  ;; Let's abstract these.
  (let ((help? (option options 'help))
        (latex? (option options 'latex))
        (metafile (option options 'metafile))
        (output (option options 'output))
        (repo (option options 'repo))
        (pdf? (option options 'pdf)))
    (cond (help? (usage))
          ((null? files) (usage 1))
          (latex?
           (if output
               (with-output-to-file output
                 (lambda () (parse-and-write tex-write-docexprs files)))
               (parse-and-write tex-write-docexprs files)))
          (pdf?
           (let ((output-directory (create-temporary-directory))
                 (current-directory (current-directory)))
             (with-working-directory output-directory
               (lambda ()
                 (dotimes (pass 3)
                   (with-output-to-pipe
                    (format "xelatex -shell-escape -output-directory=~a"
                            output-directory)
                    (lambda ()
                      (parse-and-write
                       tex-write-docexprs
                       (map (lambda (file)
                              (if (absolute-pathname? file)
                                  file
                                  (make-pathname current-directory file)))
                            files)))))))
             (when output
               (file-copy (make-pathname output-directory "texput.pdf")
                          output
                          #t))))
          (else
           (if output
               (with-output-to-file output
                 (lambda () (parse-and-write wiki-write-docexprs files metafile repo)))
               (parse-and-write wiki-write-docexprs files metafile repo))))))
