# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](http://keepachangelog.com/en/1.0.0/)
and this project adheres to [Semantic
Versioning](http://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.7.0] - 2022-09-23
### Added
- new resource_authors option that lets you select which created_by values you will match. Defaults to sensu-flow
- added contribured documentation for using docker image for alternative CI/CD workflows.

### Changed
- Fixed bug using api-key for auth.
- Added additional verbose logging for troubleshooting.

## [0.6.0] - 2022-07-01
### Changed
- refactored envar/option names to match existing sensuctl envvars

### Added
- support for api_key based auth

### Deprecated
- user/pass auth is now deprecated in favor of api_key based auth

## [0.5.0] - 2021-03-01

### Breaking Chnages
- No breaking changes (still pre-1.0)

### Added
- Added new option to disable TLS certificate verification in sensuctl and curl commands. Useful when using non-production sensu-backend instances with self-signed certificates.

### Fixed
- Updated prune logic for better error handling if prune command fails


## Reference Categories
### Added 
- for new features.
### Changed 
- for changes in existing functionality.
### Deprecated 
- for soon-to-be removed features.
### Removed 
- for now removed features.
### Fixed 
- for any bug fixes.
### Security 
- in case of vulnerabilities

