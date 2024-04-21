## [Unreleased]

- Add experimental_ractor_rspec_integration mode. Be careful, it's quite experimental.
- Fix a bug: consider a case when a backtrace is nil.
- Allow to pass a predicate block keyword arguments with destruction.

## [0.2.0] - 2024-04-17

- Add verbose mode. It's useful to debug the test case.
 
## [0.1.1] - 2024-04-14

- Change default worker from `:ractor` to `:none`

## [0.1.0] - 2024-04-13

- Implement basic primitive arbitraries
- Implement composite arbitraries
- Support shrinking
- Support multiple concurrency methods
    - Ractor
    - Process
    - Thread
    - None (Run tests sequentially)
- Documentation
    - Add better examples
    - Arbitrary usage
    - Configuration
 
## [0.0.1] - 2024-01-27

- Initial release (Proof of concept)
