# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

PBT (Property-Based Testing) is a Ruby gem that provides property-based testing capabilities with experimental features for parallel test execution using Ractor. The gem allows developers to specify properties that code should satisfy and automatically generates test cases to verify these properties.

## Development Commands

### Setup
```bash
bundle install
```

### Testing
```bash
# Run all tests
bundle exec rspec

# Run a specific test file
bundle exec rspec spec/path/to/spec.rb

# Run tests matching a pattern
bundle exec rspec -e "pattern"
```

### Linting
```bash
# Check code style
bundle exec rake standard

# Auto-fix code style issues
bundle exec rake standard:fix
```

### Combined Testing and Linting
```bash
# Default rake task runs both tests and linting
bundle exec rake
```

### Benchmarking
```bash
# Run all benchmarks
bundle exec rake benchmark:all

# Run specific benchmark categories
bundle exec rake benchmark:success:simple
bundle exec rake benchmark:success:cpu_bound
bundle exec rake benchmark:success:io_bound
bundle exec rake benchmark:failure:simple
```

### Building and Releasing
```bash
# Build the gem
bundle exec rake build

# Install locally
bundle exec rake install

# Release to RubyGems (maintainers only)
bundle exec rake release
```

## Architecture

### Core Components

1. **Arbitrary** (`lib/pbt/arbitrary/`)
   - Base classes and modules for generating random values
   - Implements various arbitraries: integer, array, tuple, hash, etc.
   - Each arbitrary knows how to generate values and shrink them

2. **Check** (`lib/pbt/check/`)
   - `Property`: Defines properties to test
   - `Runner`: Executes properties with different concurrency methods
   - `Configuration`: Global and per-run configuration
   - `Tosser`: Manages the generation and shrinking process

3. **Reporter** (`lib/pbt/reporter/`)
   - Handles test result reporting
   - Provides verbose mode for detailed output

### Key Design Patterns

- **Shrinking**: When a test fails, PBT attempts to find the minimal failing case by systematically reducing the input
- **Concurrency**: Supports both serial (`:none`) and parallel (`:ractor`) execution
- **Configuration**: Uses both global configuration and per-assertion overrides

### Testing Approach

The codebase uses RSpec for testing and follows these patterns:
- Unit tests for each arbitrary type in `spec/pbt/arbitrary/`
- Integration tests in `spec/e2e/`
- Property-based tests are used to test the library itself

### Important Notes

- Ruby 3.1+ is required due to Ractor usage
- When using `:ractor` worker, be aware of Ractor limitations (no shared state, limited object sharing)
- The gem uses Standard Ruby for code style (configured in `.standard.yml`)
- CI runs tests against Ruby 3.1, 3.2, 3.3, and 3.4