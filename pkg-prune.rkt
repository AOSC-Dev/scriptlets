#!/usr/bin/env racket

;; Copyright 2024 Kaiyang Wu
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
;; `oma install racket`
;; `raco pkg install --auto http-easy-lib`

#lang racket/base

(require racket/cmdline
         racket/contract
         racket/function
         racket/list
         racket/string)
(require net/http-easy)

(define/contract (revdeps pkgname)
  (-> string? (listof string?))
  (define url (format "https://packages.aosc.io/revdep/~a?type=json" pkgname))
  (define res (get url))
  (define json-res
    (if (= (response-status-code res) 200)
        (response-json res)
        (error 'revdeps
               "failed to get reverse dependencies for ~a: status code ~a"
               pkgname
               (response-status-code res))))
  (define sobreaks
    (foldl (λ (p acc) (if (member p acc) acc (cons p acc)))
           '()
           (flatten (hash-ref json-res 'sobreaks))))
  (define sobreaks-circular (hash-ref json-res 'sobreaks_circular))
  (define all-sobreaks (append sobreaks sobreaks-circular))
  (define all-revdeps
    (flatten (for/list ([group (hash-ref json-res 'revdeps)])
               (for/list ([p (hash-ref group 'deps)]
                          #:when (not (member (hash-ref p 'package)
                                              all-sobreaks)))
                 (hash-ref p 'package)))))
  (append all-sobreaks all-revdeps))

(define/contract (deps pkgname)
  (-> string? (listof string?))
  (define url (format "https://packages.aosc.io/packages/~a?type=json" pkgname))
  (define res (get url))
  (define json-res
    (if (= (response-status-code res) 200)
        (response-json res)
        (error 'deps
               "failed to get dependencies for ~a: status code ~a"
               pkgname
               (response-status-code res))))
  (flatten (for/list ([group (hash-ref json-res 'dependencies)])
             (foldl (λ (p acc)
                      (define pname (list-ref p 0))
                      (if (member pname acc) acc (cons pname acc)))
                    '()
                    (hash-ref group 'packages)))))

;;(define (revdeps pkgname)
;;  (match pkgname
;;    ["test1" '("test2")]
;;    ["test2" '()]))
;;
;;(define (deps pkgname)
;;  (match pkgname
;;    ["test1" '()]
;;    ["test2" '("test1")]))

(define/contract (queue-foldl proc init lst)
  (-> (-> any/c list? (values any/c list?)) any/c list? any/c)
  (define-values (acc queue) (proc init lst))
  (if (null? queue) acc (queue-foldl proc acc queue)))

(define/contract (prune pkgname)
  (-> string? (listof string?))
  (define rdeps (revdeps pkgname))
  (when (not rdeps)
    (error 'prune
           "Cannot prune ~a: package depended by ~a"
           pkgname
           (string-join rdeps ", ")))

  ; Memoization for optimizing speed where a dep is queried more than once
  (define revdeps-memo (make-hash))
  (define deps-memo (make-hash))
  (define/contract (memoized-revdeps p)
    (-> string? (listof string?))
    (when (not (hash-has-key? revdeps-memo p))
      (hash-set! revdeps-memo p (revdeps p)))
    (hash-ref revdeps-memo p))

  (define res
    (queue-foldl (λ (acc queue)
                   (define p (car queue))
                   (if (and (not (member p acc))
                            (andmap (λ (rd) (member rd acc))
                                    (memoized-revdeps p)))
                       ; when all revdeps are in the to-be-pruned list
                       (values (cons p acc) (append (deps p) (cdr queue)))
                       (values acc (cdr queue))))
                 (list)
                 (list pkgname)))
  (if (member pkgname res) res (cons pkgname res)))

(define package-to-prune
  (command-line #:program "pkg-prune.rkt" #:args (pkgname) pkgname))

(for-each displayln (prune package-to-prune))
