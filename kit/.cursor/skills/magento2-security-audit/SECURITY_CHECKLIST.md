# Security Vulnerability Checklist

Use this checklist when auditing a Magento 2 extension. Report only items with evidence in the code.

## Injection & execution

* SQL Injection
* Remote Code Execution
* Command Injection
* Unsafe `eval()`
* Dynamic code execution
* Unsafe `unserialize()` / unsafe deserialization
* Object Injection
* XXE

## File & path

* Arbitrary File Read/Write
* Path Traversal
* Unsafe file uploads
* Insecure temporary file usage

## Web & client

* XSS (Stored, Reflected, DOM)
* CSRF
* SSRF
* Open redirects
* Unsafe redirects
* XML vulnerabilities

## Auth & access

* Weak authentication
* Authorization bypass
* ACL issues
* Privilege escalation
* Missing permission checks
* Missing CSRF protection

## Data & crypto

* Sensitive information exposure
* Hardcoded credentials
* Insecure cryptography
* Weak random generation
* Session security issues

## Input & output

* Missing input validation
* Missing output escaping

## Magento-specific

* Unsafe use of Magento ObjectManager
* Dangerous direct database queries
* Unsafe shell execution
* Magento-specific security anti-patterns
* Code resembling known Magento malware techniques

## Dependencies

* Dependency vulnerabilities if visible in the code
