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
;;
;; `oma install racket`
;;
;; Usage
;;
;; This tool helps you to retire unneeded packages depended by your target
;; retiring packages of interest. For example, if `waybar` is going to be
;; retired, packages `playerctl`, `libcava`, and `power-profiles-daemon` which
;; were not depended by any other packages, will become orphans afterwards.
;; Using `pkg-prune.rkt waybar` can list these packages for you to decide their
;; fates.
;;
;; This tool would silently quit without output if the target packages have
;; reverse dependencies, which means pruning them would lead to dependency
;; breakages. In case you want to retire packages *and* their reverse
;; dependencies, check out the `dropit` tool instead.

#lang racket/base

(require racket/cmdline
         racket/contract
         racket/list
         racket/match
         racket/string)
(require json
         net/url
         net/url-connect
         openssl)

(current-https-protocol (ssl-secure-client-context))

(define/contract (extract-http-code header)
  (-> string? exact-positive-integer?)
  (match header
    [(regexp #rx"^HTTP/... ([1-9][0-9][0-9]).*" (list _ status-code))
     (string->number status-code)]
    [_ (error 'extract-http-code "invalid http header: ~a" header)]))

(define/contract (packages-site-revdeps pkgname)
  (-> string? (listof string?))
  (define url
    (string->url (format "https://packages.aosc.io/revdep/~a?type=json"
                         pkgname)))
  (define port (get-impure-port url))
  (define header (purify-port port))
  (define json-res
    (if (= (extract-http-code header) 200)
        (read-json port)
        (error 'revdeps
               "failed to get reverse dependencies for ~a: status code ~a"
               pkgname
               (extract-http-code header))))
  (flatten (for/list ([group (hash-ref json-res 'revdeps)])
             (for/list ([p (hash-ref group 'deps)])
               (hash-ref p 'package)))))

(define/contract (packages-site-deps pkgname)
  (-> string? (listof string?))
  (define url
    (string->url (format "https://packages.aosc.io/packages/~a?type=json"
                         pkgname)))
  (define port (get-impure-port url))
  (define header (purify-port port))
  (define json-res
    (if (= (extract-http-code header) 200)
        (read-json port)
        (error 'revdeps
               "failed to get dependencies for ~a: status code ~a"
               pkgname
               (extract-http-code header))))
  (flatten (for/list ([group (hash-ref json-res 'dependencies)])
             (if (or (equal? (hash-ref group 'relationship) "Breaks")
                     (equal? (hash-ref group 'relationship) "Provides"))
                 (list)
                 (foldl (λ (p acc)
                          (define pname (list-ref p 0))
                          (if (member pname acc)
                              acc
                              (cons pname acc)))
                        (list)
                        (hash-ref group 'packages))))))

;; Switch implementations here
(define revdeps packages-site-revdeps)
(define deps packages-site-deps)

(define/contract (queue-foldl proc init lst)
  (-> (-> any/c list? (values any/c list?)) any/c list? any/c)
  (define-values (acc queue) (proc init lst))
  (if (null? queue)
      acc
      (queue-foldl proc acc queue)))

(define/contract (prune pkgnames)
  (-> (listof string?) (listof string?))
  ; Memoization for optimizing speed where a dep is queried more than once
  (define revdeps-memo (make-hash))
  (define/contract (memoized-revdeps p)
    (-> string? (listof string?))
    (when (not (hash-has-key? revdeps-memo p))
      (hash-set! revdeps-memo p (revdeps p)))
    (hash-ref revdeps-memo p))

  (define res
    (queue-foldl (λ (acc queue)
                   (define p (car queue))
                   (define rdeps (memoized-revdeps p))
                   (if (or (null? rdeps)
                           (and (not (member p acc))
                                (andmap (λ (rd) (member rd acc)) rdeps)))
                       ; when all revdeps are in the to-be-pruned list
                       (values (cons p acc) (append (deps p) (cdr queue)))
                       (values acc (cdr queue))))
                 (list)
                 pkgnames))
  res)

(define packages-to-prune
  (command-line #:program "pkg-prune.rkt"
                #:args pkgnames
                (when (null? pkgnames)
                  (raise-user-error 'pkg-prune
                                    "expects at least one package name"))
                pkgnames))

(for-each displayln (prune packages-to-prune))
