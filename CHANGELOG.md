## [Unreleased]

## [0.5.1] - 2025-06-29

- Fix `IntegerArbitrary#shrink` to respect min/max bounds [#36](https://github.com/ohbarye/pbt/pull/36)

## [0.5.0] - 2024-12-30

- [Breaking change] Drop `:process` and `:thread` workers since there are no concrete use cases.
- [Breaking change] Drop `:experimental_ractor_rspec_integration` option since there are no concrete use cases.

## [0.4.2] - 2024-05-23

- Fix Prism `LoadError` message [#27](https://github.com/ohbarye/pbt/pull/27) by @sambostock

## [0.4.1] - 2024-05-10

- Fix a bug for experimental_ractor_rspec_integration mode. When a test file name starts with a number, it can't be a constant name.

## [0.4.0] - 2024-05-06

- Allow to use RSpec::Matchers for `worker: :none, :thread, :process` also.
- Make error message short to keep focusing on failure causes.
- Fix a bug for a case when parameters cannot be passed to a test block correctly.

## [0.3.0] - 2024-04-21

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
