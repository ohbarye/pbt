# Property DSL for v1

The v1 DSL is the existing explicit runner/property composition:

```ruby
Pbt.assert(seed: 42, num_runs: 100) do
  Pbt.property(Pbt.integer) do |number|
    raise "square must be nonnegative" unless number * number >= 0
  end
end
```

`Pbt.property` describes generated arguments and the predicate; `Pbt.assert`
executes it and raises `Pbt::PropertyFailure` on failure. `Pbt.check` executes
the same property and returns run details for custom reporting. A predicate
fails by raising; returning `false` alone does not fail the property.

Multiple positional arbitraries generate a tuple. Keyword arbitraries generate
a fixed hash and are passed as keyword arguments. Do not mix positional and
keyword arbitraries in a single property declaration.

```ruby
Pbt.assert do
  Pbt.property(left: Pbt.integer, right: Pbt.integer) do |left:, right:|
    raise "addition must commute" unless left + right == right + left
  end
end
```

This keeps runner options separate from generated inputs, supports existing
RSpec/Minitest assertions under `worker: :none`, and lets custom property
objects such as `Pbt.stateful` use the same runner. A shortened DSL would add
another public entry point without a demonstrated use case, so v1 keeps the
current syntax. Default execution is sequential; Ractor remains opt-in.
