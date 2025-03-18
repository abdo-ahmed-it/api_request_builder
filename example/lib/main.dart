import 'package:api_request/api_request.dart'; // Assuming ApiRequestAction is from a separate package
import 'package:api_request_builder/api_request_builder.dart'; // Your package
import 'package:flutter/material.dart';

// Define a simple response model for the example
class ExampleResponse {
  final String message;

  ExampleResponse(this.message);

  factory ExampleResponse.fromJson(Map<String, dynamic> json) {
    return ExampleResponse(json['message'] ?? 'No message');
  }
}

// Define a simple API action for the example
class ExampleAction extends ApiRequestAction<ExampleResponse> {
  @override
  RequestMethod get method => RequestMethod.GET;

  @override
  String get path => 'example'; // Mock API endpoint for demonstration

  @override
  ResponseBuilder<ExampleResponse> get responseBuilder =>
      (json) => ExampleResponse.fromJson(json);
}

void main() {
  // Configure default settings for all ApiRequestBuilder instances
  ApiRequestBuilder.config(
    enableCache: true, // Enable caching by default
    enableBackgroundFetch: false, // Disable background fetching by default
    loadingBuilder: (context) => const Center(
      child: CircularProgressIndicator(color: Colors.blue),
    ),
    errorBuilder: (context, error) => Center(
      child: Text(
        'Error occurred: $error',
        style: const TextStyle(color: Colors.red),
      ),
    ),
    emptyBuilder: (context) => const Center(
      child: Text('No data available'),
    ),
  );

  runApp(const MyApp());
}

// Main app widget
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ApiRequestBuilder Example',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: MyHomePage(),
    );
  }
}

// Home page widget demonstrating ApiRequestBuilder usage
class MyHomePage extends StatelessWidget {
  final action = ExampleAction(); // Define the action as a constant

  MyHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ApiRequestBuilder Example'),
      ),
      body: Column(
        children: [
          // Use ApiRequestBuilder to fetch and display data
          Expanded(
            child: ApiRequestBuilder(
              action: ExampleAction(),
              builder: _buildContent,
            ),
          ),
        ],
      ),
    );
  }

  // Static method to build the content based on fetched data
  static Widget _buildContent(BuildContext context, ExampleResponse data) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Center(
          child: Text(
            data.message,
            style: const TextStyle(fontSize: 18),
          ),
        ),
      ],
    );
  }
}
