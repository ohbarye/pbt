# Usage recipes

Run the standard-library examples from the repository root:

```sh
bundle exec ruby examples/usage/encodings.rb
bundle exec ruby examples/usage/disjoint_ranges.rb
```

`encodings.rb` generates ASCII strings and converts them to UTF-8, ISO-8859-1 and
Shift_JIS using a reversible `map`. ASCII is representable in all three encodings;
this example does not cover every character in those character sets. For non-ASCII
coverage, define an alphabet known to be representable in the target encoding.
Avoid `force_encoding`: it relabels bytes without converting them.

`disjoint_ranges.rb` maps integer indices to the two ranges `1..20` and `40..59`.
Each interval has twenty values, so both receive equal probability. Its inverse map
preserves shrinking in the index domain. `Pbt.choose(1..20)` handles a single range.

## FactoryBot and Faker

These libraries are optional dependencies of the example, not of pbt. Install and
run them using the dedicated bundle (Ruby 3.3 or later):

```sh
BUNDLE_GEMFILE=examples/usage/Gemfile bundle install
BUNDLE_GEMFILE=examples/usage/Gemfile bundle exec ruby examples/usage/factory_bot.rb
BUNDLE_GEMFILE=examples/usage/Gemfile bundle exec rspec examples/usage/spec/factory_bot_spec.rb
```

The example builds a fresh unsaved User with explicit generated attributes.
It uses `FactoryBot.build` without a database. PBT generates both `age` and a Faker
seed, then a new Faker RNG is installed for each case and restored in `ensure`.
Reusing the PBT seed reproduces values with the same library versions and locale.
Faker outputs may change across versions; keep your application lockfile for replay.
Do not rely on unseeded random factory defaults or sequences for values the property
checks. Generate primitive attributes first and construct objects inside the predicate;
shrinking then operates on attributes, not model instances.

The recipe uses sequential execution because Faker and FactoryBot have mutable
configuration. Test database persistence with your framework's transaction/isolation
facilities if your own property needs `FactoryBot.create`.

References: [FactoryBot attribute overrides](https://thoughtbot.github.io/factory_bot/using-factories/attribute-overrides.html),
[Faker deterministic random](https://github.com/faker-ruby/faker#deterministic-random).
