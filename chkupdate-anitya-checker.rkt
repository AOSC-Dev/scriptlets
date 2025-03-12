#!/usr/bin/env racket

;; Copyright 2025 Kaiyang Wu
;;
;; Permission is hereby granted, free of charge, to any person obtaining a copy
;; of this software and associated documentation files  (the “Software”), to
;; deal in the Software without restriction, including without limitation the
;; rights to use, copy, modify, merge, publish, distribute, sublicense, and/or
;; sell copies of the Software, and to permit persons to whom the Software is
;; furnished to do so, subject to the following conditions:
;;
;; The above copyright notice and this permission notice shall be included in
;; all copies or substantial portions of the Software.
;;
;; THE SOFTWARE IS PROVIDED “AS IS”, WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
;; IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
;; FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
;; AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
;; LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
;; FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
;; IN THE SOFTWARE.

;; Prerequisites on AOSC OS
;;
;; `oma install racket`
;;
;; Usage
;;
;; Run inside an abbs tree. It'll report potential duplicate anitya ids and some
;; warnings

#lang racket/base

(require racket/file
         racket/match
         racket/path
         racket/string)

(define all-specs
  (find-files (λ (f)
                (and (not (directory-exists? f))
                     (equal? "spec" (path->string (file-name-from-path f)))))
              (current-directory)))

(define (check-dup ids specs)
  (cond
    [(not (null? specs))
     (define lines (file->lines (car specs)))
     (define chkupdate-lines
       (filter (λ (l) (string-prefix? l "CHKUPDATE=\"anitya")) lines))
     (cond
       [(null? chkupdate-lines)
        (when (foldl (λ (l acc) (and acc (not (equal? l "DUMMYSRC=1"))))
                     #t
                     lines)
          (displayln (format "~a: WARN: No CHKUPDATE found" (car specs))))
        (check-dup ids (cdr specs))]
       [else
        (define chkupdate-line (car chkupdate-lines))
        (with-handlers ([exn:misc:match?
                         (λ (e)
                           (displayln (format "~a: WARN: Malformed CHKUPDATE"
                                              (car specs)))
                           (check-dup ids (cdr specs)))])
          (match-define (regexp #rx"CHKUPDATE=\"anitya::id=(.*)\"" (list _ id))
            chkupdate-line)
          (if (hash-has-key? ids id)
              (check-dup (hash-update ids id (λ (v) (cons (car specs) v)))
                         (cdr specs))
              (check-dup (hash-set ids id (list (car specs))) (cdr specs))))])]
    [else ids]))

(define id-specs (hash->list (check-dup (hash) all-specs)))
(for ([id-spec id-specs]
      #:when
      (and (> (length (cdr id-spec)) 1)
           (< (length (cdr id-spec)) 5)
           (foldl (λ (p acc)
                    (and acc (not (string-contains? (path->string p) "+32"))))
                  #t
                  (cdr id-spec))))
  (displayln (format "ID ~a is used by ~a"
                     (car id-spec)
                     (string-join (map path->string (cdr id-spec))))))
