# frozen_string_literal: true

D = Steep::Diagnostic

target :typecheck do
  signature "sig"
  check "test/steep_typecheck.rb"

  library "date"
  library "set" if RBS::Repository.default.lookup("set", nil)

  configure_code_diagnostics(D::Ruby.default)
end
