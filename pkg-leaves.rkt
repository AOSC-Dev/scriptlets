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
;; Run the script, and you will get all leaf nodes of the current AOSC OS
;; dependency tree (packages with no reverse dependencies).

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

(define/contract (revdeps pkgname)
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

(define/contract (all-packages)
  (-> (listof string?))
  (define url (string->url "https://packages.aosc.io/list.json"))
  (define port (get-impure-port url))
  (define header (purify-port port))
  (define json-res
    (if (= (extract-http-code header) 200)
        (read-json port)
        (error 'all-packages
               "failed to get the list of all packages: status code ~a"
               (extract-http-code header))))
  (remove-duplicates
   (filter-map (λ (package)
                 (and (equal? (hash-ref package 'branch) "stable")
                      (hash-ref package 'name)))
               (hash-ref json-res 'packages)))
  )

(define cli
  (command-line #:program "pkg-leaves.rkt"
                #:usage-help
                "get all leaf nodes on the dependency tree (packages with no
                reverse dependencies)"
                ))

(for ([package (in-list (all-packages))])
  (when (null? (revdeps package))
      (displayln package)))
