import 'dart:io';
import 'dart:convert';

/// Script to run tests and generate HTML report from JSON results
void main() async {
  print('🚀 Starting tests and generating HTML report...\n');

  // Run tests with JSON reporter
  print('📋 Running Unit Tests...');
  final unitTestJson = await runFlutterTestWithJson('test/unit/', 'unit_tests.json');
  
  print('\n📋 Running Integration Tests...');
  final integrationTestDir = Directory('integration_test');
  final integrationTestDirExists = integrationTestDir.existsSync();
  
  // Try to get available device for integration tests
  String? deviceId;
  if (integrationTestDirExists) {
    try {
      final devicesResult = await Process.run('flutter', ['devices'], runInShell: true);
      final devicesOutput = devicesResult.stdout.toString();
      
      // Try to find Windows desktop device first
      // Format: "Windows (desktop) • windows • windows-x64    • Microsoft Windows..."
      // Device ID is the second part (after first •)
      final lines = devicesOutput.split('\n');
      for (final line in lines) {
        if (line.contains('Windows (desktop)') || (line.contains('windows') && line.contains('•'))) {
          // Extract device ID (second part after first •)
          final parts = line.trim().split('•');
          if (parts.length >= 2) {
            deviceId = parts[1].trim(); // Second part is the device ID
            break;
          }
        }
      }
      
      // If no Windows device found, try to get first available device
      if (deviceId == null) {
        for (final line in lines) {
          if (line.contains('•') && !line.contains('Found') && !line.contains('Run "flutter') && line.trim().isNotEmpty) {
            final parts = line.trim().split('•');
            if (parts.length >= 2) {
              deviceId = parts[1].trim(); // Second part is usually the device ID
              break;
            }
          }
        }
      }
      
      if (deviceId != null) {
        print('   ℹ️  Using device: $deviceId');
      }
    } catch (e) {
      // If can't get device list, continue without device
      print('   ℹ️  Could not detect device, trying without device specification...');
    }
  }
  
  final integrationTestJson = integrationTestDirExists
      ? await runFlutterTestWithJson('integration_test/', 'integration_tests.json', deviceId: deviceId)
      : null;
  
  if (integrationTestJson == null && integrationTestDirExists) {
    
  } else if (!integrationTestDirExists) {
    
  }

  // Parse results from JSON files
  final testResults = <TestGroup>[];
  if (unitTestJson != null) {
    testResults.addAll(await parseJsonTestResults(unitTestJson, 'test/unit', 'Unit Tests'));
  }
  if (integrationTestJson != null) {
    testResults.addAll(await parseJsonTestResults(integrationTestJson, 'integration_test', 'Integration Tests'));
  } else if (integrationTestDirExists) {
    // If no JSON output but directory exists, parse integration tests from files without JSON data
    final emptyJson = <String, dynamic>{'tests': []};
    testResults.addAll(await parseJsonTestResults(emptyJson, 'integration_test', 'Integration Tests'));
  }

  // Generate HTML report from JSON
  print('\n📊 Generating HTML report from JSON...');
  await generateHtmlReportFromJson(testResults, unitTestJson, integrationTestJson);

  final totalTests = testResults.fold<int>(
    0,
    (sum, group) => sum + group.functions.fold<int>(
      0,
      (sum, func) => sum + func.testCases.length,
    ),
  );
  
  final passedTests = testResults.fold<int>(
    0,
    (sum, group) => sum + group.functions.fold<int>(
      0,
      (sum, func) => sum + func.testCases.where((tc) => tc.status == 'passed').length,
    ),
  );

  final failedTests = totalTests - passedTests;
  final allSuccess = failedTests == 0;
  
  print('\n✅ Completed!');
  print('   - Total tests: $totalTests');
  print('   - Passed: $passedTests');
  print('   - Failed: $failedTests');
  print('   - Report saved at: test_report.html');
  
  if (!allSuccess) {
    print('\n⚠️  Some tests failed. Please check the output above for details.');
    if (failedTests > 0) {
      exit(1);
    }
  } else {
    print('\n🎉 All tests passed!');
  }
}

/// Run Flutter test with JSON reporter and save results to JSON file
Future<Map<String, dynamic>?> runFlutterTestWithJson(String testPath, String jsonFileName, {String? deviceId}) async {
  try {
    final deviceFlag = deviceId != null ? ' -d $deviceId' : '';
    print('   Running: flutter test $testPath --reporter json$deviceFlag');
    
    // Create temporary JSON file
    final jsonFile = File(jsonFileName);
    
    final args = ['test', testPath, '--reporter', 'json'];
    if (deviceId != null) {
      args.addAll(['-d', deviceId]);
    }
    
    final result = await Process.run(
      'flutter',
      args,
      runInShell: true,
    );

    // Flutter test with JSON reporter outputs JSON to stdout
    final jsonOutput = result.stdout.toString();
    
    if (jsonOutput.isEmpty) {
      print('   ⚠️  No JSON output from tests');
      return null;
    }

    // Save JSON to file
    await jsonFile.writeAsString(jsonOutput);
    print('   ✅ Saved JSON results to: $jsonFileName');

    // Parse JSON - Flutter test JSON reporter can output JSONL (one JSON object per line)
    // Filter out non-JSON lines (like "Edge (web) • edge • web-javascript...")
    try {
      // Try to parse as a single JSON object
      final jsonData = jsonDecode(jsonOutput) as Map<String, dynamic>;
      return jsonData;
    } catch (e) {
      // If not, try parsing line by line (JSONL format)
      final lines = jsonOutput.split('\n');
      if (lines.isEmpty) {
        print('   ⚠️  No JSON data in output');
        return null;
      }
      
      // Find summary line (usually the last line with type: 'done')
      Map<String, dynamic>? summaryData;
      final allTests = <Map<String, dynamic>>[];
      int jsonLineCount = 0;
      
      for (final line in lines) {
        final trimmedLine = line.trim();
        
        // Skip empty lines
        if (trimmedLine.isEmpty) continue;
        
        // Only parse lines starting with { or [ (valid JSON)
        if (!trimmedLine.startsWith('{') && !trimmedLine.startsWith('[')) {
          continue;
        }
        
        // Skip lines with special characters that are not JSON (like bullet points •)
        // Also skip common Flutter output lines
        if (trimmedLine.contains('•') || 
            trimmedLine.contains('â€¢') ||
            trimmedLine.contains('Edge (web)') ||
            trimmedLine.contains('web-javascript') ||
            trimmedLine.contains('Windows (desktop)') ||
            trimmedLine.contains('Resolving dependencies') ||
            trimmedLine.contains('Downloading packages') ||
            trimmedLine.contains('Got dependencies') ||
            trimmedLine.contains('packages have newer versions') ||
            trimmedLine.contains('More than one device') ||
            trimmedLine.contains('Try `flutter pub') ||
            trimmedLine.startsWith('  ') && !trimmedLine.startsWith('{')) {
          continue;
        }
        
        try {
          final jsonData = jsonDecode(trimmedLine) as Map<String, dynamic>;
          jsonLineCount++;
          
          final type = jsonData['type'] as String?;
          
          if (type == 'done' || type == 'summary') {
            summaryData = jsonData;
          } else if (type == 'testStart' || type == 'testDone' || type == 'test') {
            allTests.add(jsonData);
          } else if (jsonData.containsKey('tests')) {
            // This could be a summary object
            summaryData = jsonData;
          } else if (jsonData.containsKey('successCount') || jsonData.containsKey('failureCount')) {
            // This is a summary object
            summaryData = jsonData;
          }
        } catch (e2) {
          // Skip lines that are not valid JSON (don't print error as they might be normal text)
          continue;
        }
      }
      
      // If no JSON found
      if (jsonLineCount == 0) {
        return null;
      }
      
      // If summary found, use it
      if (summaryData != null) {
        // If summary doesn't have tests array, add from allTests
        if (!summaryData.containsKey('tests') && allTests.isNotEmpty) {
          summaryData['tests'] = allTests;
        }
        return summaryData;
      }
      
      // Process testStart and testDone to calculate duration
      final testStartTimes = <int, int>{}; // testID -> startTime
      final processedTests = <Map<String, dynamic>>[];
      
      for (final test in allTests) {
        final type = test['type'] as String?;
        final testID = test['testID'] as int? ?? test['test']?['id'] as int?;
        
        if (type == 'testStart' && testID != null) {
          final time = test['time'] as int?;
          if (time != null) {
            testStartTimes[testID] = time;
          }
        } else if (type == 'testDone' && testID != null) {
          final doneTime = test['time'] as int?;
          final startTime = testStartTimes[testID];
          
          if (doneTime != null && startTime != null) {
            // Tính duration = testDone.time - testStart.time
            final duration = doneTime - startTime;
            test['duration'] = duration;
            processedTests.add(test);
          } else if (doneTime != null) {
            // If no startTime, use doneTime
            test['duration'] = doneTime;
            processedTests.add(test);
          }
        } else if (type == 'test') {
          processedTests.add(test);
        }
      }
      
      // If no summary but have tests, create summary object
      if (processedTests.isNotEmpty) {
        return {
          'tests': processedTests,
          'successCount': processedTests.where((t) => (t['result'] as String?) == 'success').length,
          'failureCount': processedTests.where((t) => (t['result'] as String?) == 'error' || (t['result'] as String?) == 'failure').length,
        };
      }
      
      print('   ⚠️  No test data found in JSON output');
      return null;
    }
  } catch (e) {
    print('   ❌ Error running tests: $e');
    return null;
  }
}

Map<String, dynamic> parseTestOutput(String output) {
  final result = <String, dynamic>{
    'passed': 0,
    'failed': 0,
    'total': 0,
    'failedTests': <String>[],
    'testTimes': <String, String>{}, // Map test name -> time
  };

  // Parse pattern: "00:13 +51 -8: Some tests failed."
  // Format: time +passed -failed: message
  final summaryPattern = RegExp(r'(\d+:\d+)\s*\+\s*(\d+)\s*-\s*(\d+):');
  final match = summaryPattern.allMatches(output).lastOrNull;
  
  if (match != null) {
    result['passed'] = int.tryParse(match.group(2) ?? '0') ?? 0;
    result['failed'] = int.tryParse(match.group(3) ?? '0') ?? 0;
    result['total'] = (result['passed'] as int) + (result['failed'] as int);
  }

  // Parse test times and failed test names
  // Pattern: "00:00 +1: Test name" or "00:00 +0 -1: Test name [E]"
  // Find all lines with format: time +number or time +number -number
  final lines = output.split('\n');
  String? previousTime;
  String? previousTestName;
  
  for (final line in lines) {
    // Pattern: "00:00 +1: Test name" hoặc "00:00 +0 -1: Test name [E]"
    final testLinePattern = RegExp(r'(\d+:\d+)\s*\+\s*(\d+)(?:\s*-\s*(\d+))?:\s*(.+?)(?:\s*\[E\])?$');
    final match = testLinePattern.firstMatch(line);
    
    if (match != null) {
      final time = match.group(1) ?? '';
      final testName = match.group(4)?.trim() ?? '';
      final isError = match.group(3) != null; // Has -number means there's an error
      
      if (testName.isNotEmpty && 
          !testName.startsWith('loading') && 
          !testName.startsWith('(setUpAll)') &&
          !testName.startsWith('(tearDownAll)') &&
          !testName.contains('All tests') &&
          !testName.contains('Some tests')) {
        
        // Get the last part of test name (after colon)
        final parts = testName.split(':');
        String cleanName = parts.length > 1 ? parts.last.trim() : testName;
        
        // Remove file path if present
        if (cleanName.contains('test/') || cleanName.contains('integration_test/')) {
          final pathParts = cleanName.split('/');
          cleanName = pathParts.last;
        }
        
        if (cleanName.isNotEmpty) {
          // Calculate test execution time (current time - previous time)
          String duration = '<1s';
          if (previousTime != null) {
            duration = calculateDurationMs(previousTime, time);
          }
          
          // Extract actual test case name from output
          // Format: "StorageService - Save and get string (saveString/getString) Save and get string successfully"
          // Need to get: "Save and get string successfully"
          
          String testCaseName = cleanName;
          
          // Find part after closing parenthesis if exists
          // Example: "... (saveString/getString) Save and get string successfully"
          final parenIndex = cleanName.lastIndexOf(')');
          if (parenIndex != -1 && parenIndex < cleanName.length - 1) {
            testCaseName = cleanName.substring(parenIndex + 1).trim();
          } else {
            // If no parenthesis, find part after last dash
            final dashIndex = cleanName.lastIndexOf(' - ');
            if (dashIndex != -1) {
              final afterDash = cleanName.substring(dashIndex + 3).trim();
              // Split into parts and get test case name (usually the last part)
              // Format: "FunctionName TestCaseName" or just "TestCaseName"
              final words = afterDash.split(' ');
              if (words.length >= 2) {
                // Get last 3-5 words (usually the test case name)
                final startIdx = words.length > 5 ? words.length - 5 : 0;
                testCaseName = words.sublist(startIdx).join(' ');
              } else {
                testCaseName = afterDash;
              }
            }
          }
          
          // Save time with multiple keys for easier matching
          final testTimesMap = result['testTimes'] as Map<String, String>;
          
          // 1. Save with full name from output
          testTimesMap[cleanName] = duration;
          
          // 2. Save with extracted test case name (part after parenthesis or after function name)
          if (testCaseName.isNotEmpty && testCaseName != cleanName) {
            testTimesMap[testCaseName] = duration;
          }
          
          // 3. Save with variants of test case name for better matching
          final nameWords = testCaseName.split(' ').where((w) => w.isNotEmpty).toList();
          if (nameWords.length >= 2) {
            // Save last 2 words
            final last2Words = nameWords.sublist(nameWords.length - 2).join(' ');
            testTimesMap[last2Words] = duration;
            
            // Save last 3 words
            if (nameWords.length >= 3) {
              final last3Words = nameWords.sublist(nameWords.length - 3).join(' ');
              testTimesMap[last3Words] = duration;
            }
            
            // Save last 4 words
            if (nameWords.length >= 4) {
              final last4Words = nameWords.sublist(nameWords.length - 4).join(' ');
              testTimesMap[last4Words] = duration;
            }
          }
          
          // 4. Save each important word (skip short words like "and", "with", etc.)
          for (final word in nameWords) {
            if (word.length > 3 && !['and', 'with', 'from', 'to', 'of'].contains(word.toLowerCase())) {
              testTimesMap[word] = duration;
            }
          }
          
          // If there's an error, add to failed list
          if (isError && !(result['failedTests'] as List<String>).contains(cleanName)) {
            (result['failedTests'] as List<String>).add(cleanName);
          }
          
          previousTime = time;
          previousTestName = cleanName;
        }
      }
    }
  }

  return result;
}

String calculateDurationMs(String startTime, String endTime) {
  try {
    final startParts = startTime.split(':');
    final endParts = endTime.split(':');
    
    if (startParts.length == 2 && endParts.length == 2) {
      final startMinutes = int.parse(startParts[0]);
      final startSeconds = int.parse(startParts[1]);
      final endMinutes = int.parse(endParts[0]);
      final endSeconds = int.parse(endParts[1]);
      
      final startTotalMs = (startMinutes * 60 + startSeconds) * 1000;
      final endTotalMs = (endMinutes * 60 + endSeconds) * 1000;
      
      final diffMs = endTotalMs - startTotalMs;
      
      // If diffMs <= 0, test ran very fast
      if (diffMs <= 0) {
        return '<1ms';
      } else if (diffMs < 1000) {
        return '${diffMs}ms';
      } else if (diffMs < 60000) {
        // Under 1 minute: show both seconds and milliseconds
        final seconds = diffMs ~/ 1000;
        final ms = diffMs % 1000;
        if (ms > 0) {
          return '${seconds}s ${ms}ms';
        } else {
          return '${seconds}s';
        }
      } else {
        // Over 1 minute: show minutes, seconds and milliseconds
        final minutes = diffMs ~/ 60000;
        final remainingMs = diffMs % 60000;
        final seconds = remainingMs ~/ 1000;
        final ms = remainingMs % 1000;
        
        if (seconds > 0 && ms > 0) {
          return '${minutes}m ${seconds}s ${ms}ms';
        } else if (seconds > 0) {
          return '${minutes}m ${seconds}s';
        } else if (ms > 0) {
          return '${minutes}m ${ms}ms';
        } else {
          return '${minutes}m';
        }
      }
    }
  } catch (e) {
    // Ignore parse errors
  }
  
  return 'N/A';
}

/// Parse test results from JSON
Future<List<TestGroup>> parseJsonTestResults(
  Map<String, dynamic> jsonData,
  String testDir,
  String category,
) async {
  final testGroups = <TestGroup>[];
  final dir = Directory(testDir);
  
  if (!dir.existsSync()) {
    return testGroups;
  }

  // Get test list from JSON
  final tests = jsonData['tests'] as List<dynamic>? ?? [];
  final testMap = <String, Map<String, dynamic>>{};
  
  // Create map from JSON for easy lookup
  for (final test in tests) {
    if (test is Map<String, dynamic>) {
      // Get test name from test object or testDone
      String? name;
      if (test.containsKey('test') && test['test'] is Map) {
        name = (test['test'] as Map)['name'] as String?;
      } else {
        name = test['name'] as String?;
      }
      
      if (name != null && name.isNotEmpty && !name.startsWith('loading') && name != '(setUpAll)') {
        // Save with full name
        testMap[name] = test;
        
        // Save with name variants for easier matching
        // Remove path and get only test name
        final nameParts = name.split(' ');
        if (nameParts.isNotEmpty) {
          final lastPart = nameParts.last;
          if (lastPart.isNotEmpty && !testMap.containsKey(lastPart)) {
            testMap[lastPart] = test;
          }
        }
        
        // Save with format: "GroupName - TestName"
        if (name.contains(' - ')) {
          final parts = name.split(' - ');
          if (parts.length >= 2) {
            final testNameOnly = parts.last.trim();
            if (testNameOnly.isNotEmpty && !testMap.containsKey(testNameOnly)) {
              testMap[testNameOnly] = test;
            }
          }
        }
      }
    }
  }

  // Parse from test files and match with JSON data
  await for (final entity in dir.list(recursive: true)) {
    if (entity is File && entity.path.endsWith('_test.dart')) {
      final content = await entity.readAsString();
      final group = parseTestFileFromJson(content, entity.path, testMap);
      if (group.functions.isNotEmpty) {
        testGroups.add(group);
      }
    }
  }

  return testGroups;
}

Future<List<TestGroup>> parseTestResults(
  TestRunResult result,
  String testDir,
  String category,
) async {
  final testGroups = <TestGroup>[];
  final dir = Directory(testDir);
  
  if (!dir.existsSync()) {
    return testGroups;
  }

  // Parse from test files
  await for (final entity in dir.list(recursive: true)) {
    if (entity is File && entity.path.endsWith('_test.dart')) {
      final content = await entity.readAsString();
      final group = parseTestFile(content, entity.path, result);
      if (group.functions.isNotEmpty) {
        testGroups.add(group);
      }
    }
  }

  return testGroups;
}

/// Parse test file from JSON data
TestGroup parseTestFileFromJson(
  String content,
  String filePath,
  Map<String, Map<String, dynamic>> jsonTestMap,
) {
  final fileName = filePath.split(Platform.pathSeparator).last.replaceAll('_test.dart', '');
  final groupName = fileName.split('_').map((word) {
    if (word.isEmpty) return '';
    return word[0].toUpperCase() + word.substring(1);
  }).join(' ');

  final group = TestGroup(
    name: groupName,
    filePath: filePath,
    functions: [],
  );

  // Parse groups
  final groupPattern = RegExp(
    r"group\('([^']+)'[^)]*\)\s*\{",
    multiLine: true,
  );

  final groupMatches = groupPattern.allMatches(content);
  
  for (final groupMatch in groupMatches) {
    final functionName = groupMatch.group(1) ?? '';
    
    // Find start and end position of group
    final groupStart = groupMatch.end;
    var braceCount = 1;
    var groupEnd = groupStart;
    
    for (var i = groupStart; i < content.length && braceCount > 0; i++) {
      if (content[i] == '{') braceCount++;
      if (content[i] == '}') braceCount--;
      if (braceCount == 0) {
        groupEnd = i;
        break;
      }
    }
    
    final groupContent = content.substring(groupStart, groupEnd);
    
    // Parse test cases in group
    final testPattern = RegExp(
      r"test(Widgets)?\('([^']+)'",
      multiLine: true,
    );
    
    final testMatches = testPattern.allMatches(groupContent);
    final testCases = <TestCase>[];
    
    for (final match in testMatches) {
      final testName = match.group(2) ?? '';
      final testStart = match.end;
      
      // Find test code block
      var braceCount = 0;
      var foundOpen = false;
      var testEnd = testStart;
      
      for (var i = testStart; i < groupContent.length; i++) {
        if (groupContent[i] == '{') {
          braceCount++;
          foundOpen = true;
        } else if (groupContent[i] == '}') {
          braceCount--;
          if (foundOpen && braceCount == 0) {
            testEnd = i + 1;
            break;
          }
        }
      }
      
      final testCode = testEnd > testStart 
          ? groupContent.substring(testStart, testEnd)
          : '';
      
      // Parse detailed information from test code
      final details = parseTestDetails(testName, testCode);
      
      // Find test in JSON map
      Map<String, dynamic>? jsonTest;
      String? status;
      String? duration;
      
      // Find match in JSON (may have different formats)
      // Try exact match first
      if (jsonTestMap.containsKey(testName)) {
        jsonTest = jsonTestMap[testName];
      } else {
        // Try match with variants
        for (final entry in jsonTestMap.entries) {
          final jsonTestName = entry.key.toLowerCase();
          final testNameLower = testName.toLowerCase();
          
          // Match if test name contains JSON name or vice versa
          if (jsonTestName.contains(testNameLower) || 
              testNameLower.contains(jsonTestName) ||
              jsonTestName.endsWith(testNameLower) ||
              testNameLower.endsWith(jsonTestName)) {
            jsonTest = entry.value;
            break;
          }
        }
      }
      
      if (jsonTest != null) {
        // Get status from JSON
        final result = jsonTest['result'] as String?;
        if (result == 'success' || result == 'passed') {
          status = 'passed';
        } else if (result == 'error' || result == 'failure' || result == 'failed') {
          status = 'failed';
        } else {
          status = 'passed'; // Default
        }
        
        // Get duration from JSON - duration is already calculated (testDone.time - testStart.time)
        int? timeMs;
        
        // First try to get duration field (already calculated)
        if (jsonTest.containsKey('duration')) {
          final durationValue = jsonTest['duration'];
          if (durationValue is int) {
            timeMs = durationValue;
          } else if (durationValue is double) {
            timeMs = durationValue.toInt();
          } else if (durationValue is String) {
            timeMs = int.tryParse(durationValue);
          }
        }
        
        // Format duration - always show milliseconds
        if (timeMs != null && timeMs > 0) {
          if (timeMs < 1000) {
            duration = '${timeMs}ms';
          } else if (timeMs < 60000) {
            final seconds = timeMs ~/ 1000;
            final ms = timeMs % 1000;
            duration = '${seconds}s ${ms}ms';
          } else {
            final minutes = timeMs ~/ 60000;
            final remaining = timeMs % 60000;
            final seconds = remaining ~/ 1000;
            final ms = remaining % 1000;
            duration = '${minutes}m ${seconds}s ${ms}ms';
          }
        } else {
          duration = '0ms';
        }
      } else {
        status = 'passed'; // Default if not found in JSON
        duration = '0ms';
      }
      
      testCases.add(TestCase(
        name: testName,
        status: status ?? 'passed',
        duration: duration ?? '0ms',
        details: details,
      ));
    }

    if (testCases.isNotEmpty) {
      group.functions.add(TestFunction(
        name: functionName,
        testCases: testCases,
      ));
    }
  }

  // If no group, find test cases directly
  if (group.functions.isEmpty) {
    final testPattern = RegExp(
      r"test(Widgets)?\('([^']+)'",
      multiLine: true,
    );
    
    final testMatches = testPattern.allMatches(content);
    final testCases = <TestCase>[];
    
    for (final match in testMatches) {
      final testName = match.group(2) ?? '';
      final testStart = match.end;
      
      // Find test code block
      var braceCount = 0;
      var foundOpen = false;
      var testEnd = testStart;
      
      for (var i = testStart; i < content.length; i++) {
        if (content[i] == '{') {
          braceCount++;
          foundOpen = true;
        } else if (content[i] == '}') {
          braceCount--;
          if (foundOpen && braceCount == 0) {
            testEnd = i + 1;
            break;
          }
        }
      }
      
      final testCode = testEnd > testStart 
          ? content.substring(testStart, testEnd)
          : '';
      
      final details = parseTestDetails(testName, testCode);
      
      // Find test in JSON map
      Map<String, dynamic>? jsonTest;
      String? status;
      String? duration;
      
      // Try exact match first
      if (jsonTestMap.containsKey(testName)) {
        jsonTest = jsonTestMap[testName];
      } else {
        // Try match with variants
        for (final entry in jsonTestMap.entries) {
          final jsonTestName = entry.key.toLowerCase();
          final testNameLower = testName.toLowerCase();
          
          // Match if test name contains JSON name or vice versa
          if (jsonTestName.contains(testNameLower) || 
              testNameLower.contains(jsonTestName) ||
              jsonTestName.endsWith(testNameLower) ||
              testNameLower.endsWith(jsonTestName)) {
            jsonTest = entry.value;
            break;
          }
        }
      }
      
      if (jsonTest != null) {
        final result = jsonTest['result'] as String?;
        if (result == 'success' || result == 'passed') {
          status = 'passed';
        } else if (result == 'error' || result == 'failure' || result == 'failed') {
          status = 'failed';
        } else {
          status = 'passed';
        }
        
        // Get duration from JSON - duration is already calculated (testDone.time - testStart.time)
        int? timeMs;
        
        // First try to get duration field (already calculated)
        if (jsonTest.containsKey('duration')) {
          final durationValue = jsonTest['duration'];
          if (durationValue is int) {
            timeMs = durationValue;
          } else if (durationValue is double) {
            timeMs = durationValue.toInt();
          } else if (durationValue is String) {
            timeMs = int.tryParse(durationValue);
          }
        }
        
        // Format duration - always show milliseconds
        if (timeMs != null && timeMs > 0) {
          if (timeMs < 1000) {
            duration = '${timeMs}ms';
          } else if (timeMs < 60000) {
            final seconds = timeMs ~/ 1000;
            final ms = timeMs % 1000;
            duration = '${seconds}s ${ms}ms';
          } else {
            final minutes = timeMs ~/ 60000;
            final remaining = timeMs % 60000;
            final seconds = remaining ~/ 1000;
            final ms = remaining % 1000;
            duration = '${minutes}m ${seconds}s ${ms}ms';
          }
        } else {
          duration = '0ms';
        }
      } else {
        status = 'passed';
        duration = '0ms';
      }
      
      testCases.add(TestCase(
        name: testName,
        status: status ?? 'passed',
        duration: duration ?? '0ms',
        details: details,
      ));
    }

    if (testCases.isNotEmpty) {
      group.functions.add(TestFunction(
        name: 'Tests',
        testCases: testCases,
      ));
    }
  }

  return group;
}

TestGroup parseTestFile(String content, String filePath, TestRunResult testResult) {
  final fileName = filePath.split(Platform.pathSeparator).last.replaceAll('_test.dart', '');
  final groupName = fileName.split('_').map((word) {
    if (word.isEmpty) return '';
    return word[0].toUpperCase() + word.substring(1);
  }).join(' ');

  final group = TestGroup(
    name: groupName,
    filePath: filePath,
    functions: [],
  );

  // Parse groups
  final groupPattern = RegExp(
    r"group\('([^']+)'[^)]*\)\s*\{",
    multiLine: true,
  );

  final groupMatches = groupPattern.allMatches(content);
  
  for (final groupMatch in groupMatches) {
    final functionName = groupMatch.group(1) ?? '';
    
    // Find start and end position of group
    final groupStart = groupMatch.end;
    var braceCount = 1;
    var groupEnd = groupStart;
    
    for (var i = groupStart; i < content.length && braceCount > 0; i++) {
      if (content[i] == '{') braceCount++;
      if (content[i] == '}') braceCount--;
      if (braceCount == 0) {
        groupEnd = i;
        break;
      }
    }
    
    final groupContent = content.substring(groupStart, groupEnd);
    
    // Parse test cases in group
    final testPattern = RegExp(
      r"test(Widgets)?\('([^']+)'",
      multiLine: true,
    );
    
    final testMatches = testPattern.allMatches(groupContent);
    final testCases = <TestCase>[];
    
    for (final match in testMatches) {
      final testName = match.group(2) ?? '';
      final testStart = match.end;
      
      // Find test code block (from after test('name', to });
      var braceCount = 0;
      var foundOpen = false;
      var testEnd = testStart;
      
      for (var i = testStart; i < groupContent.length; i++) {
        if (groupContent[i] == '{') {
          braceCount++;
          foundOpen = true;
        } else if (groupContent[i] == '}') {
          braceCount--;
          if (foundOpen && braceCount == 0) {
            testEnd = i + 1;
            break;
          }
        }
      }
      
      final testCode = testEnd > testStart 
          ? groupContent.substring(testStart, testEnd)
          : '';
      
      // Parse detailed information from test code
      final details = parseTestDetails(testName, testCode);
      // Check if this test is in the failed list
      // More flexible comparison because test name may have different formats
      final isFailed = testResult.failedTests.any((failed) {
        final failedClean = failed.toLowerCase().trim();
        final testClean = testName.toLowerCase().trim();
        // Check if test name contains failed name or vice versa
        return failedClean.contains(testClean) || 
               testClean.contains(failedClean) ||
               failedClean.endsWith(testClean) ||
               testClean.endsWith(failedClean);
      });
      
      // Default is passed if not in failed list
      // Only mark as failed if actually in failedTests
      final status = isFailed ? 'failed' : 'passed';
      
      // Get test execution time - find flexible match
      String duration = '<1s'; // Default
      
      // Try exact match first
      if (testResult.testTimes.containsKey(testName)) {
        duration = testResult.testTimes[testName]!;
      } else {
        // Find match by comparing parts of test name
        final testNameLower = testName.toLowerCase();
        final testWords = testName.split(' ').where((w) => w.isNotEmpty).toList();
        
        // Try match with variants of test name
        bool found = false;
        
        // 1. Try match with last 2-4 words
        for (int i = 2; i <= 4 && i <= testWords.length && !found; i++) {
          final lastWords = testWords.sublist(testWords.length - i).join(' ');
          if (testResult.testTimes.containsKey(lastWords)) {
            duration = testResult.testTimes[lastWords]!;
            found = true;
            break;
          }
        }
        
        // 2. If not found, try match by comparing each word
        if (!found) {
          for (final entry in testResult.testTimes.entries) {
            final keyLower = entry.key.toLowerCase();
            final testNameLower = testName.toLowerCase();
            
            // Kiểm tra nếu test name chứa key hoặc ngược lại
            if (testNameLower.contains(keyLower) || keyLower.contains(testNameLower)) {
              // Kiểm tra độ tương đồng (ít nhất 50% từ khớp)
              final keyWords = entry.key.toLowerCase().split(' ').where((w) => w.length > 2).toList();
              final testWordsLower = testWords.map((w) => w.toLowerCase()).where((w) => w.length > 2).toList();
              
              int matchCount = 0;
              for (final keyWord in keyWords) {
                if (testWordsLower.any((tw) => tw.contains(keyWord) || keyWord.contains(tw))) {
                  matchCount++;
                }
              }
              
              if (matchCount >= (keyWords.length / 2).ceil() || matchCount >= (testWordsLower.length / 2).ceil()) {
                duration = entry.value;
                found = true;
                break;
              }
            }
          }
        }
        
        // 3. Nếu vẫn chưa tìm thấy, thử match với từng từ quan trọng
        if (!found) {
          for (final word in testWords.reversed) {
            if (word.length > 3 && testResult.testTimes.containsKey(word)) {
              duration = testResult.testTimes[word]!;
              found = true;
              break;
            }
          }
        }
      }
      
      testCases.add(TestCase(
        name: testName,
        status: status,
        duration: duration,
        details: details,
      ));
    }

    if (testCases.isNotEmpty) {
      group.functions.add(TestFunction(
        name: functionName,
        testCases: testCases,
      ));
    }
  }

  // If no group, find test cases directly
  if (group.functions.isEmpty) {
    final testPattern = RegExp(
      r"test(Widgets)?\('([^']+)'",
      multiLine: true,
    );
    
    final testMatches = testPattern.allMatches(content);
    final testCases = <TestCase>[];
    
    for (final match in testMatches) {
      final testName = match.group(2) ?? '';
      final testStart = match.end;
      
      // Find test code block
      var braceCount = 0;
      var foundOpen = false;
      var testEnd = testStart;
      
      for (var i = testStart; i < content.length; i++) {
        if (content[i] == '{') {
          braceCount++;
          foundOpen = true;
        } else if (content[i] == '}') {
          braceCount--;
          if (foundOpen && braceCount == 0) {
            testEnd = i + 1;
            break;
          }
        }
      }
      
      final testCode = testEnd > testStart 
          ? content.substring(testStart, testEnd)
          : '';
      
      final details = parseTestDetails(testName, testCode);
      
      // Check if this test is in the failed list
      final isFailed = testResult.failedTests.any((failed) {
        final failedClean = failed.toLowerCase().trim();
        final testClean = testName.toLowerCase().trim();
        return failedClean.contains(testClean) || 
               testClean.contains(failedClean) ||
               failedClean.endsWith(testClean) ||
               testClean.endsWith(failedClean);
      });
      
      // Default is passed if not in failed list
      final status = isFailed ? 'failed' : 'passed';
      
      // Get test execution time - find flexible match
      String duration = '0ms'; // Default
      
      // Try exact match first
      if (testResult.testTimes.containsKey(testName)) {
        duration = testResult.testTimes[testName]!;
      } else {
        // Find match by comparing parts of test name
        final testNameLower = testName.toLowerCase();
        final testWords = testName.split(' ').where((w) => w.isNotEmpty).toList();
        
        // Try match with variants of test name
        bool found = false;
        
        // 1. Try match with last 2-4 words
        for (int i = 2; i <= 4 && i <= testWords.length && !found; i++) {
          final lastWords = testWords.sublist(testWords.length - i).join(' ');
          if (testResult.testTimes.containsKey(lastWords)) {
            duration = testResult.testTimes[lastWords]!;
            found = true;
            break;
          }
        }
        
        // 2. If not found, try match by comparing each word
        if (!found) {
          for (final entry in testResult.testTimes.entries) {
            final keyLower = entry.key.toLowerCase();
            final testNameLower = testName.toLowerCase();
            
            // Check if test name contains key or vice versa
            if (testNameLower.contains(keyLower) || keyLower.contains(testNameLower)) {
              // Check similarity (at least 50% words match)
              final keyWords = entry.key.toLowerCase().split(' ').where((w) => w.length > 2).toList();
              final testWordsLower = testWords.map((w) => w.toLowerCase()).where((w) => w.length > 2).toList();
              
              int matchCount = 0;
              for (final keyWord in keyWords) {
                if (testWordsLower.any((tw) => tw.contains(keyWord) || keyWord.contains(tw))) {
                  matchCount++;
                }
              }
              
              if (matchCount >= (keyWords.length / 2).ceil() || matchCount >= (testWordsLower.length / 2).ceil()) {
                duration = entry.value;
                found = true;
                break;
              }
            }
          }
        }
        
        // 3. If still not found, try match with each important word
        if (!found) {
          for (final word in testWords.reversed) {
            if (word.length > 3 && testResult.testTimes.containsKey(word)) {
              duration = testResult.testTimes[word]!;
              found = true;
              break;
            }
          }
        }
      }
      
      testCases.add(TestCase(
        name: testName,
        status: status,
        duration: duration,
        details: details,
      ));
    }

    if (testCases.isNotEmpty) {
      group.functions.add(TestFunction(
        name: 'Tests',
        testCases: testCases,
      ));
    }
  }

  return group;
}

/// Tạo báo cáo HTML từ JSON data
Future<void> generateHtmlReportFromJson(
  List<TestGroup> testResults,
  Map<String, dynamic>? unitJson,
  Map<String, dynamic>? integrationJson,
) async {
  final totalTests = testResults.fold<int>(
    0,
    (sum, group) => sum + group.functions.fold<int>(
      0,
      (sum, func) => sum + func.testCases.length,
    ),
  );

  final totalFunctions = testResults.fold<int>(
    0,
    (sum, group) => sum + group.functions.length,
  );

  final passedTests = testResults.fold<int>(
    0,
    (sum, group) => sum + group.functions.fold<int>(
      0,
      (sum, func) => sum + func.testCases.where((tc) => tc.status == 'passed').length,
    ),
  );

  final failedTests = totalTests - passedTests;
  final successRate = totalTests > 0 ? (passedTests / totalTests * 100).toStringAsFixed(1) : '0.0';

  // Lấy thông tin từ JSON nếu có
  int unitPassed = 0;
  int unitFailed = 0;
  int integrationPassed = 0;
  int integrationFailed = 0;
  
  if (unitJson != null) {
    final successCount = unitJson['successCount'] as int? ?? 0;
    final failureCount = unitJson['failureCount'] as int? ?? 0;
    unitPassed = successCount;
    unitFailed = failureCount;
  }
  
  if (integrationJson != null) {
    final successCount = integrationJson['successCount'] as int? ?? 0;
    final failureCount = integrationJson['failureCount'] as int? ?? 0;
    integrationPassed = successCount;
    integrationFailed = failureCount;
  }

  final html = _generateHtmlContent(testResults, totalTests, totalFunctions, passedTests, failedTests, successRate);

  final file = File('test_report.html');
  await file.writeAsString(html);
  print('   ✅ Generated HTML report from JSON: test_report.html');
}

/// Helper function to generate HTML content
String _generateHtmlContent(
  List<TestGroup> testResults,
  int totalTests,
  int totalFunctions,
  int passedTests,
  int failedTests,
  String successRate,
) {
  return '''
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Test Report - AI Detection App</title>
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }
        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            padding: 20px;
            min-height: 100vh;
        }
        .container {
            max-width: 1400px;
            margin: 0 auto;
            background: white;
            border-radius: 12px;
            box-shadow: 0 10px 40px rgba(0,0,0,0.2);
            overflow: hidden;
        }
        .header {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            padding: 40px;
            text-align: center;
        }
        .header h1 {
            font-size: 2.8em;
            margin-bottom: 10px;
            text-shadow: 2px 2px 4px rgba(0,0,0,0.2);
        }
        .header .subtitle {
            font-size: 1.2em;
            opacity: 0.95;
        }
        .stats {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(220px, 1fr));
            gap: 20px;
            padding: 30px;
            background: #f8f9fa;
        }
        .stat-card {
            background: white;
            padding: 25px;
            border-radius: 10px;
            text-align: center;
            box-shadow: 0 4px 15px rgba(0,0,0,0.1);
            transition: transform 0.3s;
        }
        .stat-card:hover {
            transform: translateY(-5px);
        }
        .stat-card .number {
            font-size: 3em;
            font-weight: bold;
            color: #667eea;
            margin-bottom: 10px;
        }
        .stat-card .label {
            color: #666;
            font-size: 1.1em;
            font-weight: 500;
        }
        .content {
            padding: 30px;
        }
        .test-group {
            margin-bottom: 30px;
            border: 1px solid #e0e0e0;
            border-radius: 10px;
            overflow: hidden;
            box-shadow: 0 2px 8px rgba(0,0,0,0.1);
        }
        .test-group-header {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            padding: 20px;
            font-size: 1.4em;
            font-weight: bold;
            display: flex;
            justify-content: space-between;
            align-items: center;
        }
        .test-group-header .file-path {
            font-size: 0.7em;
            opacity: 0.9;
            font-weight: normal;
        }
        .test-function {
            margin: 20px;
            border-left: 4px solid #667eea;
            padding-left: 20px;
            background: #f8f9fa;
            border-radius: 5px;
            padding: 15px;
        }
        .test-function-name {
            font-size: 1.2em;
            font-weight: 600;
            color: #333;
            margin-bottom: 15px;
            padding-bottom: 10px;
            border-bottom: 2px solid #e0e0e0;
        }
        .test-case {
            padding: 12px 15px;
            margin: 8px 0;
            background: white;
            border-radius: 6px;
            display: flex;
            align-items: center;
            gap: 15px;
            box-shadow: 0 1px 3px rgba(0,0,0,0.1);
            transition: all 0.2s;
            cursor: pointer;
        }
        .test-case:hover {
            box-shadow: 0 2px 6px rgba(0,0,0,0.15);
            transform: translateX(5px);
        }
        .test-case.passed {
            border-left: 4px solid #28a745;
        }
        .test-case.failed {
            border-left: 4px solid #dc3545;
        }
        .test-case.pending {
            border-left: 4px solid #ffc107;
        }
        .status-badge {
            padding: 5px 15px;
            border-radius: 15px;
            font-size: 0.85em;
            font-weight: 600;
            min-width: 80px;
            text-align: center;
        }
        .status-badge.passed {
            background: #d4edda;
            color: #155724;
        }
        .status-badge.failed {
            background: #f8d7da;
            color: #721c24;
        }
        .status-badge.pending {
            background: #fff3cd;
            color: #856404;
        }
        .test-case-name {
            flex: 1;
            color: #333;
            font-size: 1em;
        }
        .test-case-duration {
            color: #666;
            font-size: 0.85em;
            padding: 2px 8px;
            background: #f0f0f0;
            border-radius: 10px;
            font-weight: 500;
        }
        .footer {
            text-align: center;
            padding: 30px;
            background: #f8f9fa;
            color: #666;
            border-top: 2px solid #e0e0e0;
        }
        .timestamp {
            margin-top: 10px;
            font-size: 0.95em;
            color: #999;
        }
        .summary {
            background: #e7f3ff;
            padding: 20px;
            border-radius: 8px;
            margin-bottom: 30px;
            border-left: 4px solid #667eea;
        }
        .summary h2 {
            color: #333;
            margin-bottom: 15px;
        }
        .summary p {
            color: #666;
            line-height: 1.6;
        }
        .warning {
            background: #fff3cd;
            padding: 15px;
            border-radius: 8px;
            margin-bottom: 20px;
            border-left: 4px solid #ffc107;
        }
        .warning strong {
            color: #856404;
        }
        .success {
            background: #d4edda;
            padding: 15px;
            border-radius: 8px;
            margin-bottom: 20px;
            border-left: 4px solid #28a745;
        }
        .success strong {
            color: #155724;
        }
        .modal {
            display: none;
            position: fixed;
            z-index: 1000;
            left: 0;
            top: 0;
            width: 100%;
            height: 100%;
            background-color: rgba(0,0,0,0.5);
            animation: fadeIn 0.3s;
        }
        .modal-content {
            background-color: white;
            margin: 5% auto;
            padding: 30px;
            border-radius: 12px;
            width: 90%;
            max-width: 700px;
            box-shadow: 0 10px 40px rgba(0,0,0,0.3);
            animation: slideDown 0.3s;
            max-height: 80vh;
            overflow-y: auto;
        }
        .modal-header {
            display: flex;
            justify-content: space-between;
            align-items: center;
            margin-bottom: 20px;
            padding-bottom: 15px;
            border-bottom: 2px solid #e0e0e0;
        }
        .modal-header h2 {
            color: #333;
            font-size: 1.8em;
        }
        .close {
            color: #aaa;
            font-size: 28px;
            font-weight: bold;
            cursor: pointer;
            line-height: 20px;
        }
        .close:hover {
            color: #000;
        }
        .modal-body {
            color: #666;
            line-height: 1.8;
        }
        .detail-item {
            margin: 15px 0;
            padding: 12px;
            background: #f8f9fa;
            border-radius: 8px;
            border-left: 4px solid #667eea;
        }
        .detail-label {
            font-weight: 600;
            color: #333;
            margin-bottom: 5px;
        }
        .detail-value {
            color: #666;
            font-family: 'Courier New', monospace;
            background: white;
            padding: 8px;
            border-radius: 4px;
            margin-top: 5px;
        }
        @keyframes fadeIn {
            from { opacity: 0; }
            to { opacity: 1; }
        }
        @keyframes slideDown {
            from {
                transform: translateY(-50px);
                opacity: 0;
            }
            to {
                transform: translateY(0);
                opacity: 1;
            }
        }
    </style>
</head>
<body>
    <div id="testModal" class="modal">
        <div class="modal-content">
            <div class="modal-header">
                <h2 id="modalTitle">Test Case Details</h2>
                <span class="close" onclick="closeModal()">&times;</span>
            </div>
            <div class="modal-body" id="modalBody">
            </div>
        </div>
    </div>
    <div class="container">
        <div class="header">
            <h1>📊 Test Report</h1>
            <div class="subtitle">AI Detection App - Flutter Application (From JSON)</div>
        </div>
        <div class="stats">
            <div class="stat-card">
                <div class="number">${testResults.length}</div>
                <div class="label">Test Groups</div>
            </div>
            <div class="stat-card">
                <div class="number">$totalFunctions</div>
                <div class="label">Functions</div>
            </div>
            <div class="stat-card">
                <div class="number" style="color: #28a745;">$passedTests</div>
                <div class="label">Passed Tests</div>
            </div>
            <div class="stat-card">
                <div class="number" style="color: #dc3545;">$failedTests</div>
                <div class="label">Failed Tests</div>
            </div>
            <div class="stat-card">
                <div class="number" style="color: #667eea;">$successRate%</div>
                <div class="label">Success Rate</div>
            </div>
        </div>
        <div class="content">
            <div class="summary">
                <h2>📋 Overview</h2>
                <p>
                    This report is generated from <strong>Flutter test JSON results</strong>.
                    There are a total of <strong>$totalTests test cases</strong> divided into 
                    <strong>${testResults.length} test groups</strong> and <strong>$totalFunctions functions</strong>.
                </p>
                ${failedTests > 0 
                    ? '<div class="warning"><strong>⚠️ Warning:</strong> $failedTests tests failed. Please check the terminal output for error details.</div>'
                    : '<div class="success"><strong>✅ Success:</strong> All $passedTests tests passed!</div>'}
            </div>
            ${testResults.map((group) => _generateGroupHtml(group)).join('')}
        </div>
        <div class="footer">
            <div style="font-size: 1.1em; font-weight: 600; margin-bottom: 10px;">
                Generated by AI Detection Test Runner (JSON)
            </div>
            <div class="timestamp">
                ${DateTime.now().toString().split('.')[0]}
            </div>
        </div>
    </div>
    <script>
        function showTestDetails(name, status, duration, details) {
            const modal = document.getElementById('testModal');
            const modalTitle = document.getElementById('modalTitle');
            const modalBody = document.getElementById('modalBody');
            
            modalTitle.textContent = name;
            
            let html = '<div class="detail-item">';
            html += '<div class="detail-label">📊 Status:</div>';
            html += '<div class="detail-value">' + status.toUpperCase() + '</div>';
            html += '</div>';
            
            
            // Display detailed information
            if (details && Object.keys(details).length > 0) {
                html += '<div class="detail-item">';
                html += '<div class="detail-label">📋 Details:</div>';
                html += '<div style="margin-top: 10px;">';
                
                if (details.stringLength) {
                    html += '<div style="margin: 8px 0;"><strong>String Length:</strong> ' + details.stringLength + ' characters';
                    if (details.stringChar) {
                        html += ' (character: "' + details.stringChar + '")';
                    }
                    html += '</div>';
                }
                
                if (details.listItems) {
                    html += '<div style="margin: 8px 0;"><strong>Number of Items:</strong> ' + details.listItems;
                    if (details.listContent) {
                        html += '<br><strong>Content:</strong> [' + details.listContent + ']';
                    }
                    html += '</div>';
                }
                
                if (details.generatedCount) {
                    html += '<div style="margin: 8px 0;"><strong>Generated Count:</strong> ' + details.generatedCount + ' items</div>';
                }
                
                if (details.itemCount) {
                    html += '<div style="margin: 8px 0;"><strong>Item Count:</strong> ' + details.itemCount + ' items</div>';
                }
                
                if (details.delay) {
                    html += '<div style="margin: 8px 0;"><strong>Delay:</strong> ' + details.delay + '</div>';
                }
                
                // Display other values
                for (const [key, value] of Object.entries(details)) {
                    if (!['stringLength', 'stringChar', 'listItems', 'listContent', 'generatedCount', 'itemCount', 'delay'].includes(key)) {
                        html += '<div style="margin: 8px 0;"><strong>' + key + ':</strong> ' + value + '</div>';
                    }
                }
                
                html += '</div></div>';
            } else {
                html += '<div class="detail-item">';
                html += '<div style="color: #999; font-style: italic;">No additional details available</div>';
                html += '</div>';
            }
            
            modalBody.innerHTML = html;
            modal.style.display = 'block';
        }
        
        function closeModal() {
            document.getElementById('testModal').style.display = 'none';
        }
        
        // Đóng modal khi click bên ngoài
        window.onclick = function(event) {
            const modal = document.getElementById('testModal');
            if (event.target == modal) {
                modal.style.display = 'none';
            }
        }
        
        // Đóng modal bằng phím ESC
        document.addEventListener('keydown', function(event) {
            if (event.key === 'Escape') {
                closeModal();
            }
        });
    </script>
</body>
</html>
''';
}

Future<void> generateHtmlReport(
  List<TestGroup> testResults,
  TestRunResult unitResult,
  TestRunResult integrationResult,
) async {
  final totalTests = testResults.fold<int>(
    0,
    (sum, group) => sum + group.functions.fold<int>(
      0,
      (sum, func) => sum + func.testCases.length,
    ),
  );

  final totalFunctions = testResults.fold<int>(
    0,
    (sum, group) => sum + group.functions.length,
  );

  final passedTests = testResults.fold<int>(
    0,
    (sum, group) => sum + group.functions.fold<int>(
      0,
      (sum, func) => sum + func.testCases.where((tc) => tc.status == 'passed').length,
    ),
  );

  final failedTests = totalTests - passedTests;
  final successRate = totalTests > 0 ? (passedTests / totalTests * 100).toStringAsFixed(1) : '0.0';

  final html = _generateHtmlContent(testResults, totalTests, totalFunctions, passedTests, failedTests, successRate);

  final file = File('test_report.html');
  await file.writeAsString(html);
}

String _generateGroupHtml(TestGroup group) {
  final totalTestsInGroup = group.functions.fold<int>(
    0,
    (sum, func) => sum + func.testCases.length,
  );
  
  final passedInGroup = group.functions.fold<int>(
    0,
    (sum, func) => sum + func.testCases.where((tc) => tc.status == 'passed').length,
  );

  return '''
    <div class="test-group">
        <div class="test-group-header">
            <span>${group.name}</span>
            <span class="file-path">${group.filePath} ($passedInGroup/$totalTestsInGroup passed)</span>
        </div>
        ${group.functions.map((func) => _generateFunctionHtml(func)).join('')}
    </div>
  ''';
}

String _generateFunctionHtml(TestFunction function) {
  final passedCount = function.testCases.where((tc) => tc.status == 'passed').length;
  return '''
    <div class="test-function">
        <div class="test-function-name">🔹 ${function.name} ($passedCount/${function.testCases.length} passed)</div>
        ${function.testCases.map((testCase) => _generateTestCaseHtml(testCase)).join('')}
    </div>
  ''';
}

String _generateTestCaseHtml(TestCase testCase) {
  // Create JSON string for details to use in JavaScript
  final detailsJson = testCase.details.entries.map((e) => 
    '"${e.key}": ${e.value is String ? '"${e.value.toString().replaceAll('"', '\\"')}"' : e.value}'
  ).join(', ');
  
  return '''
    <div class="test-case ${testCase.status}" 
         onclick="showTestDetails('${testCase.name.replaceAll("'", "\\'")}', '${testCase.status}', '${testCase.duration}', {${detailsJson}})">
        <span class="status-badge ${testCase.status}">${testCase.status.toUpperCase()}</span>
        <span class="test-case-name">${testCase.name}</span>
    </div>
  ''';
}

class TestRunResult {
  final bool success;
  final String output;
  final int passedCount;
  final int failedCount;
  final int totalCount;
  final List<String> failedTests;
  final Map<String, String> testTimes; // Map test name -> duration

  TestRunResult({
    required this.success,
    required this.output,
    required this.passedCount,
    required this.failedCount,
    required this.totalCount,
    required this.failedTests,
    required this.testTimes,
  });
}

class TestGroup {
  final String name;
  final String filePath;
  final List<TestFunction> functions;

  TestGroup({
    required this.name,
    required this.filePath,
    required this.functions,
  });
}

class TestFunction {
  final String name;
  final List<TestCase> testCases;

  TestFunction({
    required this.name,
    required this.testCases,
  });
}

class TestCase {
  final String name;
  final String status;
  final String duration;
  final Map<String, dynamic> details;

  TestCase({
    required this.name,
    required this.status,
    this.duration = 'N/A',
    this.details = const {},
  });
}

Map<String, dynamic> parseTestDetails(String testName, String testCode) {
  final details = <String, dynamic>{};
  
  if (testCode.isEmpty) return details;
  
  // Parse các giá trị số
  // Tìm pattern: 'a' * 1000 (chuỗi dài)
  final longStringPattern = RegExp(r"'([^']+)'\s*\*\s*(\d+)");
  final longStringMatch = longStringPattern.firstMatch(testCode);
  if (longStringMatch != null) {
    final char = longStringMatch.group(1) ?? '';
    final length = int.tryParse(longStringMatch.group(2) ?? '0') ?? 0;
    details['stringLength'] = length;
    details['stringChar'] = char;
  }
  
  // Parse số lượng items trong list
  final listPattern = RegExp(r"\[(.*?)\]");
  final listMatches = listPattern.allMatches(testCode);
  for (final match in listMatches) {
    final listContent = match.group(1) ?? '';
    if (listContent.contains(',')) {
      final items = listContent.split(',').where((item) => item.trim().isNotEmpty).toList();
      if (items.length > 0) {
        details['listItems'] = items.length;
        details['listContent'] = items.take(3).join(', ') + (items.length > 3 ? '...' : '');
      }
    }
  }
  
  // Parse giá trị cụ thể
  final valuePattern = RegExp(r"const\s+(\w+)\s*=\s*([\x27\x22])([^\x27\x22]+)\1");
  final valueMatches = valuePattern.allMatches(testCode);
  for (final match in valueMatches) {
    final key = match.group(1) ?? '';
    final value = match.group(3) ?? ''; // group(2) là quote, group(3) là value
    if (key.contains('key') || key.contains('value') || key.contains('email') || key.contains('password')) {
      details[key] = value;
    }
  }
  
  // Parse số lượng (ví dụ: List.generate(120, ...))
  final generatePattern = RegExp(r"List\.generate\((\d+)");
  final generateMatch = generatePattern.firstMatch(testCode);
  if (generateMatch != null) {
    final count = int.tryParse(generateMatch.group(1) ?? '0') ?? 0;
    details['generatedCount'] = count;
  }
  
  // Parse duration (ví dụ: Duration(seconds: 1))
  final durationPattern = RegExp(r"Duration\((\w+):\s*(\d+)\)");
  final durationMatch = durationPattern.firstMatch(testCode);
  if (durationMatch != null) {
    final unit = durationMatch.group(1) ?? '';
    final value = int.tryParse(durationMatch.group(2) ?? '0') ?? 0;
    details['delay'] = '$value $unit';
  }
  
  // Parse số lượng plants, farms, etc.
  if (testCode.contains('plants') || testCode.contains('farms')) {
    final countPattern = RegExp(r"(\d+)\s*(?:plants?|farms?)", caseSensitive: false);
    final countMatch = countPattern.firstMatch(testCode);
    if (countMatch != null) {
      final count = int.tryParse(countMatch.group(1) ?? '0') ?? 0;
      details['itemCount'] = count;
    }
  }
  
  return details;
}
