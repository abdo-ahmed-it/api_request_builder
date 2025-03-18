# ApiRequestBuilder

A Flutter package that simplifies API requests with built-in caching, background fetching, and customizable UI rendering. It seamlessly integrates with the `api_request` package and provides a flexible widget for handling data fetching and display.

## Features

- **Easy API Integration**: Use with `ApiRequestAction` or any `Future` to fetch data.
- **Caching Support**: Store responses in memory to reduce redundant requests.
- **Background Fetching**: Automatically refresh data in the background when enabled.
- **Global Configuration**: Set default settings for all instances using `ApiRequestBuilder.config()`.
- **Customizable UI**: Define builders for loading, error, empty, and success states.
- **Refresh Capability**: Manually refresh data with `ApiRequestBuilder.refresh()`.

## Installation

Add `api_request_builder` to your `pubspec.yaml`:

```yaml
dependencies:
  api_request_builder: ^0.1.0  # Replace with the latest version
  api_request: ^x.x.x  # Required dependency, replace with the version you use
```

Then run:

```sh
flutter pub get
```

## Usage

### Basic Example

Fetch and display data from an API using `ApiRequestBuilder`:

```dart
import 'package:api_request/api_request.dart';
import 'package:api_request_builder/api_request_builder.dart';
import 'package:flutter/material.dart';

class ExampleResponse {
  final String message;
  ExampleResponse(this.message);
  factory ExampleResponse.fromJson(Map<String, dynamic> json) => ExampleResponse(json['message'] ?? '');
}

class ExampleAction extends ApiRequestAction<ExampleResponse> {
  @override
  RequestMethod get method => RequestMethod.GET;
  @override
  String get path => 'example';
  @override
  ResponseBuilder<ExampleResponse> get responseBuilder => (json) => ExampleResponse.fromJson(json);
}

void main() {
  runApp(MaterialApp(home: MyHomePage()));
}

class MyHomePage extends StatelessWidget {
  final action = ExampleAction();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('ApiRequestBuilder Demo')),
      body: ApiRequestBuilder(
        action: action,
        builder: (context, data) => Center(child: Text(data.message)),
      ),
    );
  }
}
```

### Configuring Defaults

Set global defaults for all `ApiRequestBuilder` instances:

```dart
void main() {
  ApiRequestBuilder.config(
    enableCache: true, // Enable caching by default
    enableBackgroundFetch: false, // Disable background fetching by default
    loadingBuilder: (context) => Center(child: CircularProgressIndicator()),
    errorBuilder: (context, error) => Center(child: Text('Error: $error')),
    emptyBuilder: (context) => Center(child: Text('No data available')),
  );
  runApp(MaterialApp(home: MyHomePage()));
}
```

Now, any `ApiRequestBuilder` will use these defaults unless overridden:

```dart
ApiRequestBuilder(
  action: ExampleAction(),
  builder: (context, data) => Center(child: Text(data.message)),
  // Uses default enableCache=true and loading/error/empty builders
);
```

### Advanced Usage

Override defaults for a specific instance and customize builders:

```dart
ApiRequestBuilder(
  action: ExampleAction(),
  enableCache: false, // Override default
  enableBackgroundFetch: false, // Override default
  loadingBuilder: (context) => Center(child: CircularProgressIndicator(color: Colors.green)),
  errorBuilder: (context, error) => Center(child: Text('Failed: $error', style: TextStyle(color: Colors.red))),
  emptyBuilder: (context) => Center(child: Text('Nothing here!')),
  builder: (context, data) => Center(child: Text(data.message)),
);
```

## Example

Check out the full example in the "Example" tab on pub.dev or in the `example/` directory of this package. It demonstrates:

- Configuring defaults with `ApiRequestBuilder.config()`.
- Using `ApiRequestBuilder` with an `ApiRequestAction`.
- Refreshing data with a button.

## API Reference

### `ApiRequestBuilder`

A `StatefulWidget` that fetches and displays data.

#### Properties:

- `future`: Optional `Future<T> Function()` to fetch data.
- `action`: Optional `ApiRequestAction<T>` to fetch data.
- `builder`: **Required** `Widget Function(BuildContext, T)` to render the data.
- `loadingBuilder`: Optional builder for loading state.
- `errorBuilder`: Optional builder for error state.
- `emptyBuilder`: Optional builder for empty state.
- `enableCache`: Optional `bool` to enable caching (defaults to config value).
- `enableBackgroundFetch`: Optional `bool` to enable background fetching (defaults to config value).
- `cacheKey`: Optional `String` to specify a custom cache key.
- `requestData`: Optional `Map<String, dynamic>` for additional request data.

#### Static Methods:

- `config()`: Sets default settings for all instances.
- `refresh()`: Clears cache and refetches data.

### Notes

- **Background Fetching**: Most effective when `enableCache` is `true`, as updated data won't persist otherwise.
- **Dependencies**: Requires `api_request` for `ApiRequestAction` functionality.

## Contributing

Feel free to submit issues or pull requests on the GitHub repository. Contributions are welcome!

## License

This package is licensed under the MIT License. See the `LICENSE` file for details.

