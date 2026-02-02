# /test

Napiši ili pokreni testove.

**Agent:** Developer

## Korištenje

```
/test                      # Pokreni sve testove
/test [file]              # Pokreni specifični test
/test --write [file]      # Napiši test za fajl
/test --coverage          # Pokreni sa coverage reportom
```

## Pokreni testove

### Svi testovi
```bash
bin/rails test
```

### Specifični fajl
```bash
bin/rails test test/models/location_test.rb
```

### Specifični test
```bash
bin/rails test test/models/location_test.rb:42
```

### Pattern
```bash
bin/rails test test/controllers/curator/*
```

## Napiši testove

### 1. Identificiraj šta testirati

```ruby
# Za model
- Validacije
- Associations
- Scopes
- Instance methods
- Class methods

# Za controller
- Response status
- Rendered template
- Redirects
- Flash messages
- Database changes

# Za service
- Happy path
- Edge cases
- Error handling
```

### 2. Test struktura

```ruby
class LocationTest < ActiveSupport::TestCase
  # Setup
  setup do
    @location = locations(:mostar_stari_most)
  end

  # Validacije
  test "requires name" do
    @location.name = nil
    assert_not @location.valid?
    assert_includes @location.errors[:name], "can't be blank"
  end

  # Associations
  test "has many experiences" do
    assert_respond_to @location, :experiences
  end

  # Scopes
  test "published scope returns only published" do
    assert Location.published.all? { |l| l.status == "published" }
  end

  # Methods
  test "geocoded? returns true when has coordinates" do
    assert @location.geocoded?
  end
end
```

### 3. Fixtures

Lokacija: `test/fixtures/[model].yml`

```yaml
mostar_stari_most:
  name: Stari Most
  city: Mostar
  status: published
  latitude: 43.3372
  longitude: 17.8150
```

## Output

```
## Test Results

Ran 150 tests, 320 assertions

✓ All tests passed

# ili

✗ 2 failures, 1 error

Failures:
1. LocationTest#test_requires_name
   Expected nil to not be nil
   test/models/location_test.rb:15

Fix? [y/n]
```
