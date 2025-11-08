import 'package:flutter/material.dart';
import 'dart:math';

// --- CORE UNIT DEFINITIONS ---

// Base Units are: Byte (Data), Second (Time), Meter (Length), Unit (Number)
enum BaseType { byte, second, meter, unit, dataRate }

// Dart representation of a numerical value with an associated dimension.
class UnitValue {
  final double value;
  final BaseType baseType;
  final String? unitKey; // Original unit key for context (optional)

  UnitValue(this.value, this.baseType, {this.unitKey});

  @override
  String toString() => '$value ${baseType.toString().split('.').last}';
}

// Unit definition structure
class UnitDef {
  final BaseType base;
  final double multiplier;
  final String name;

  UnitDef(this.base, this.multiplier, this.name);
}

// Multipliers (Constants from JS)
const double dataBase = 1024.0;
const double timeBase = 60.0;

const Map<String, double> timeMultipliers = {
  'minute': 60.0,
  'hour': 3600.0,
  'day': 86400.0,
  'week': 604800.0,
};

const Map<String, int> precedence = {
  '+': 1,
  '-': 1,
  '*': 2,
  '/': 2,
};

// All Unit Definitions
final Map<String, UnitDef> units = {
  // Data Units (Base: Byte, Power of 1024)
  'b': UnitDef(BaseType.byte, 1, 'B'),
  'kb': UnitDef(BaseType.byte, dataBase, 'KB'),
  'mb': UnitDef(BaseType.byte, pow(dataBase, 2).toDouble(), 'MB'),
  'gb': UnitDef(BaseType.byte, pow(dataBase, 3).toDouble(), 'GB'),
  'tb': UnitDef(BaseType.byte, pow(dataBase, 4).toDouble(), 'TB'),
  'pb': UnitDef(BaseType.byte, pow(dataBase, 5).toDouble(), 'PB'),

  // Large Number Multipliers (Base: Unit, Power of 10)
  'thousand': UnitDef(BaseType.unit, 1e3, ''),
  'k': UnitDef(BaseType.unit, 1e3, ''),
  'million': UnitDef(BaseType.unit, 1e6, ''),
  'm': UnitDef(BaseType.unit, 1e6, ''),
  'billion': UnitDef(BaseType.unit, 1e9, ''),
  'b': UnitDef(BaseType.unit, 1e9, ''),
  'trillion': UnitDef(BaseType.unit, 1e12, ''),
  't': UnitDef(BaseType.unit, 1e12, ''),

  // Time Units (Base: Second)
  'sec': UnitDef(BaseType.second, 1, 'sec'),
  'min': UnitDef(BaseType.second, timeBase, 'min'),
  'hour': UnitDef(BaseType.second, timeBase * 60, 'hr'),
  'day': UnitDef(BaseType.second, timeBase * 60 * 24, 'day'),
  'week': UnitDef(BaseType.second, timeBase * 60 * 24 * 7, 'wk'),

  // Length Units (Base: Meter)
  'mm': UnitDef(BaseType.meter, 1e-3, 'mm'),
  'cm': UnitDef(BaseType.meter, 1e-2, 'cm'),
  'm': UnitDef(BaseType.meter, 1, 'm'),
  'km': UnitDef(BaseType.meter, 1e3, 'km'),
  'inch': UnitDef(BaseType.meter, 0.0254, 'in'),
  'ft': UnitDef(BaseType.meter, 0.3048, 'ft'),
  'yd': UnitDef(BaseType.meter, 0.9144, 'yd'),
  'mile': UnitDef(BaseType.meter, 1609.34, 'mile'),
};

// Formatting Rules (Largest to Smallest)
final Map<BaseType, List<Map<String, dynamic>>> formatUnits = {
  BaseType.byte: [
    {'limit': pow(dataBase, 5).toDouble(), 'unit': 'PB'},
    {'limit': pow(dataBase, 4).toDouble(), 'unit': 'TB'},
    {'limit': pow(dataBase, 3).toDouble(), 'unit': 'GB'},
    {'limit': pow(dataBase, 2).toDouble(), 'unit': 'MB'},
    {'limit': dataBase, 'unit': 'KB'},
    {'limit': 1.0, 'unit': 'B'}
  ].reversed.toList(),
  BaseType.second: [
    {'limit': timeBase * 60 * 24 * 7, 'unit': 'weeks'},
    {'limit': timeBase * 60 * 24, 'unit': 'days'},
    {'limit': timeBase * 60, 'unit': 'hours'},
    {'limit': timeBase, 'unit': 'minutes'},
    {'limit': 1.0, 'unit': 'seconds'}
  ].reversed.toList(),
  BaseType.meter: [
    {'limit': 1609.34, 'unit': 'miles'},
    {'limit': 1000.0, 'unit': 'km'},
    {'limit': 1.0, 'unit': 'm'},
    {'limit': 0.01, 'unit': 'cm'},
    {'limit': 0.001, 'unit': 'mm'}
  ].reversed.toList(),
  BaseType.unit: [
    {'limit': 1e12, 'unit': 'trillion'},
    {'limit': 1e9, 'unit': 'billion'},
    {'limit': 1e6, 'unit': 'million'},
    {'limit': 1e3, 'unit': 'thousand'},
    {'limit': 1.0, 'unit': ''}
  ].reversed.toList(),
};


// --- CORE CALCULATION ENGINE LOGIC ---

UnitValue _toBaseValue(double value, String unitKey) {
  final unit = units[unitKey];
  if (unit == null) {
    throw Exception('Unknown unit: $unitKey');
  }
  return UnitValue(value * unit.multiplier, unit.base, unitKey: unitKey);
}

List<dynamic> _tokenize(String input) {
  final tokenRegex = RegExp(
      r'(\d+(\.\d+)?)|([a-z]+)|([\+\-\*/\(\)])',
      caseSensitive: false);
  
  // Clean up and standardize the input string
  final cleanInput = input
      .toLowerCase()
      .replaceAllMapped(RegExp(r'([+*/()])'), (m) => ' ${m.group(0)!} ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  final matches = tokenRegex.allMatches(cleanInput);
  final tokens = matches.map((m) => m.group(0)!).toList();

  final combinedTokens = <dynamic>[];
  for (int i = 0; i < tokens.length; i++) {
    final token = tokens[i];
    final nextToken = i + 1 < tokens.length ? tokens[i + 1] : null;
    final double? parsedNumber = double.tryParse(token);

    if (parsedNumber != null) {
      // Case 1: Number followed by a Unit
      if (nextToken != null && units.containsKey(nextToken)) {
        combinedTokens.add(_toBaseValue(parsedNumber, nextToken));
        i++; // Consume the unit
      }
      // Case 2: Standalone number (Unitless)
      else {
        combinedTokens.add(UnitValue(parsedNumber, BaseType.unit));
      }
    } 
    // Case 3: Operator or Parenthesis
    else if (precedence.containsKey(token) || token == '(' || token == ')') {
      combinedTokens.add(token);
    } 
    // Case 4: Standalone unit (treat as 1 of that unit)
    else if (units.containsKey(token)) {
      combinedTokens.add(_toBaseValue(1, token));
    } else if (token.isNotEmpty) {
      // Ignore spaces/empty tokens if any survived
      throw Exception('Unrecognized token: $token');
    }
  }
  return combinedTokens;
}

List<dynamic> _shuntingYard(List<dynamic> tokens) {
  final outputQueue = <dynamic>[];
  final operatorStack = <String>[];

  for (final token in tokens) {
    if (token is UnitValue) {
      outputQueue.add(token);
    } else if (token is String) {
      final op = token;
      if (op == '(') {
        operatorStack.add(op);
      } else if (op == ')') {
        while (operatorStack.isNotEmpty && operatorStack.last != '(') {
          outputQueue.add(operatorStack.removeLast());
        }
        if (operatorStack.isEmpty || operatorStack.removeLast() != '(') {
          throw Exception("Mismatched parentheses.");
        }
      } else {
        // Standard operator logic (precedence check)
        while (
            operatorStack.isNotEmpty &&
            operatorStack.last != '(' &&
            (precedence[operatorStack.last] ?? 0) >= (precedence[op] ?? 0)) 
        {
          outputQueue.add(operatorStack.removeLast());
        }
        operatorStack.add(op);
      }
    }
  }

  while (operatorStack.isNotEmpty) {
    final op = operatorStack.removeLast();
    if (op == '(') {
      throw Exception("Mismatched parentheses.");
    }
    outputQueue.add(op);
  }

  return outputQueue;
}

UnitValue _evaluateRPN(List<dynamic> rpnTokens) {
  final stack = <UnitValue>[];

  for (final token in rpnTokens) {
    if (token is UnitValue) {
      stack.add(token);
    } else if (token is String) {
      final op = token;
      if (stack.length < 2) {
        throw Exception("Invalid expression structure (missing operand for operator $op).");
      }

      final op2 = stack.removeLast(); // Right operand
      final op1 = stack.removeLast(); // Left operand

      late double resultValue;
      BaseType resultType = BaseType.unit;

      switch (op) {
        case '+':
        case '-':
          if (op1.baseType != op2.baseType) {
            throw Exception('Cannot perform $op between different unit types: ${op1.baseType.name} and ${op2.baseType.name}.');
          }
          resultValue = op == '+' ? op1.value + op2.value : op1.value - op2.value;
          resultType = op1.baseType;
          break;

        case '*':
          resultValue = op1.value * op2.value;
          // Scalar Multiplication and Quantity Promotion
          if (op1.baseType == BaseType.unit) {
            resultType = op2.baseType;
          } else if (op2.baseType == BaseType.unit) {
            resultType = op1.baseType;
          } else if (op1.baseType != op2.baseType) {
            // Quantity by Quantity -> unitless ratio for simplicity (e.g., area, speed in base units)
            resultType = BaseType.unit;
          } else {
            // Same unit type multiplication (e.g., m * m = m^2). We simplify to unit for now.
             resultType = BaseType.unit;
          }
          break;

        case '/':
          if (op2.value == 0) throw Exception("Division by zero.");
          resultValue = op1.value / op2.value;

          if (op1.baseType == BaseType.byte && op2.baseType == BaseType.second) {
            resultType = BaseType.dataRate; // Data / Time = Special Rate
          } else if (op2.baseType == BaseType.unit) {
            resultType = op1.baseType; // Quantity / Number = Preserve Quantity Unit
          } else {
            // Quantity / Quantity (e.g., MB/GB, meter/meter, or Length/Time) = Unitless Ratio/Rate
            resultType = BaseType.unit;
          }
          break;
        default:
          throw Exception('Unsupported operator: $op');
      }

      stack.add(UnitValue(resultValue, resultType));
    }
  }

  if (stack.length != 1) {
    throw Exception("Invalid expression structure (too many operands remaining).");
  }

  return stack.first;
}

// --- FORMATTING AND UI DATA HELPERS ---

String _formatBytes(double value) {
  final rules = formatUnits[BaseType.byte]!.reversed; // Use smallest to largest
  for (final rule in rules) {
    if (value.abs() >= rule['limit']) {
      final convertedValue = value / rule['limit'];
      return '${convertedValue.toStringAsFixed(3)} ${rule['unit']}';
    }
  }
  return '${value.toStringAsFixed(3)} B'; // Fallback
}

// Formats a generic result (non-data rate)
String _formatGeneric(double value, BaseType baseType) {
  final rules = formatUnits[baseType] ?? formatUnits[BaseType.unit]!;
  final reversedRules = rules.reversed;

  // Handle unitless numbers without large multipliers (like the 'unit' type itself)
  if (baseType == BaseType.unit) {
    return value.toStringAsFixed(3);
  }

  // Handle very small numbers by returning the base value in the smallest unit
  if (value.abs() < 1) {
    final smallestRule = rules.first;
    return '${value.toStringAsFixed(3)} ${smallestRule['unit']}';
  }

  for (final rule in reversedRules) {
    if (value.abs() >= rule['limit']) {
      final convertedValue = value / rule['limit'];
      return '${convertedValue.toStringAsFixed(3)} ${rule['unit']}';
    }
  }

  return value.toStringAsFixed(3);
}

// Result structure to pass to the UI
class CalculationResult {
  final String mainDisplay;
  final String baseValueDisplay;
  final bool isDataRate;
  final List<Map<String, String>> projections;

  CalculationResult(this.mainDisplay, this.baseValueDisplay,
      {this.isDataRate = false, this.projections = const []});
}

// Main Calculation Function
CalculationResult calculateUnitExpression(String input) {
  try {
    if (input.trim().isEmpty) {
      throw Exception("Input cannot be empty.");
    }
    final tokens = _tokenize(input);
    final rpnTokens = _shuntingYard(tokens);
    final result = _evaluateRPN(rpnTokens);

    // 1. Base Value Display (for transparency)
    final baseTypeName = result.baseType.name.split('.').last;
    final baseValueDisplay =
        '(${result.value.toStringAsFixed(0)} base ${baseTypeName}s)';

    if (result.baseType == BaseType.dataRate) {
      // 2. Data Rate Special Handling
      final rateInBytesPerSecond = result.value;
      final baseRateFormatted = _formatBytes(rateInBytesPerSecond);
      final projections = <Map<String, String>>[];

      for (final period in timeMultipliers.keys) {
        final totalBytes = rateInBytesPerSecond * timeMultipliers[period]!;
        final formattedData = _formatBytes(totalBytes);
        projections.add({'period': period, 'data': formattedData});
      }

      return CalculationResult('$baseRateFormatted/second', baseValueDisplay,
          isDataRate: true, projections: projections);
    } else {
      // 3. Standard Generic Formatting
      final formattedResult = _formatGeneric(result.value, result.baseType);
      return CalculationResult(formattedResult, baseValueDisplay);
    }
  } catch (e) {
    throw Exception(e.toString().replaceAll('Exception: ', ''));
  }
}

// --- FLUTTER UI IMPLEMENTATION ---

void main() {
  runApp(const UnitSenseApp());
}

class UnitSenseApp extends StatelessWidget {
  const UnitSenseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'UnitSense Calculator',
      theme: ThemeData(
        primarySwatch: Colors.indigo,
        fontFamily: 'Inter',
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.indigo,
          foregroundColor: Colors.white,
        ),
      ),
      home: const CalculatorScreen(),
    );
  }
}

class CalculatorScreen extends StatefulWidget {
  const CalculatorScreen({super.key});

  @override
  State<CalculatorScreen> createState() => _CalculatorScreenState();
}

class _CalculatorScreenState extends State<CalculatorScreen> {
  final TextEditingController _controller =
      TextEditingController(text: '10 GB / hour');
  CalculationResult? _result;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _calculate(); // Run initial example on load
  }

  void _calculate() {
    setState(() {
      _result = null;
      _errorMessage = null;
    });

    if (_controller.text.isEmpty) {
      setState(() {
        _errorMessage = "Please enter an expression.";
      });
      return;
    }

    try {
      final result = calculateUnitExpression(_controller.text);
      setState(() {
        _result = result;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xfff7f7f9),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Container(
            width: double.infinity,
            constraints: const BoxConstraints(maxWidth: 500),
            padding: const EdgeInsets.all(32.0),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16.0),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.2),
                  spreadRadius: 5,
                  blurRadius: 15,
                  offset: const Offset(0, 5),
                ),
              ],
              border: Border.all(color: Colors.grey.shade100),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'UnitSense Calculator',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF4338CA), // Indigo 700
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Supports complex math, unit consistency, and Data Rate Projections.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 24),

                // Input Section
                TextField(
                  controller: _controller,
                  keyboardType: TextInputType.text,
                  onSubmitted: (_) => _calculate(),
                  style: const TextStyle(fontSize: 20),
                  decoration: InputDecoration(
                    labelText: 'Enter Expression',
                    labelStyle: const TextStyle(
                        fontSize: 16, color: Color(0xFF4338CA)),
                    hintText: 'Try: (5 GB - 100 MB) / 10',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8.0),
                      borderSide: const BorderSide(color: Color(0xFF818CF8)), // Indigo 300
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8.0),
                      borderSide: const BorderSide(
                          color: Color(0xFF4338CA), width: 2.0),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _calculate,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4F46E5), // Indigo 600
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16.0),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                    elevation: 5,
                  ),
                  child: const Text(
                    'Calculate',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(height: 24),

                // Result or Error Display
                if (_errorMessage != null)
                  Container(
                    padding: const EdgeInsets.all(16.0),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      border: Border(
                          left: BorderSide(
                              color: Colors.red.shade500, width: 4)),
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Calculation Error',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.red)),
                        const SizedBox(height: 4),
                        Text(_errorMessage!,
                            style: const TextStyle(color: Colors.red)),
                      ],
                    ),
                  )
                else if (_result != null)
                  _buildResultDisplay(_result!)
                else
                  const SizedBox.shrink(),

                const SizedBox(height: 24),

                // Info Section
                _buildInfoSection(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildResultDisplay(CalculationResult result) {
    return Container(
      padding: const EdgeInsets.all(24.0),
      decoration: BoxDecoration(
        color: const Color(0xFFEEF2FF), // Indigo 50
        border: Border(
            left: BorderSide(
                color: Colors.indigo.shade400, width: 4)),
        borderRadius: BorderRadius.circular(8.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Result:',
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF4F46E5))),
          const SizedBox(height: 4),

          // Main Display (Data Rate or Standard)
          Text(
            result.mainDisplay,
            style: const TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.bold,
                color: Colors.black87),
            softWrap: true,
          ),
          const SizedBox(height: 8),

          // Base Value Display
          Text(
            result.baseValueDisplay,
            style: const TextStyle(fontSize: 14, color: Colors.grey),
          ),
          const SizedBox(height: 16),

          // Projections (only for Data Rate)
          if (result.isDataRate && result.projections.isNotEmpty)
            _buildProjections(result.projections),
        ],
      ),
    );
  }

  Widget _buildProjections(List<Map<String, String>> projections) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Storage Projections',
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Color(0xFF4338CA))),
        const SizedBox(height: 10),
        Column(
          children: projections.map((proj) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Container(
                padding: const EdgeInsets.all(12.0),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8.0),
                  border: Border.all(color: Colors.grey.shade100),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.05),
                      spreadRadius: 1,
                      blurRadius: 5,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(proj['period']!.toUpperCase(),
                        style: const TextStyle(
                            fontWeight: FontWeight.w500,
                            color: Colors.black54)),
                    Text(proj['data']!,
                        style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF4F46E5))),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildInfoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(color: Colors.grey),
        const SizedBox(height: 16),
        const Text(
          'Supported Units:',
          style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.black87),
        ),
        const SizedBox(height: 8),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 3.5,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          children: const [
            InfoChip(
                text: 'Data: B, KB, MB, GB, TB, PB (1024-based)',
                color: Color(0xFFF0F9FF)), // Sky 50
            InfoChip(
                text: 'Numbers: thousand, million, billion (k, m, b, t)',
                color: Color(0xFFFEFCE8)), // Yellow 50
            InfoChip(
                text: 'Time: sec, min, hour, day, week',
                color: Color(0xFFF0FFF4)), // Emerald 50
            InfoChip(
                text: 'Length: mm, cm, m, km, inch, ft, yd, mile',
                color: Color(0xFFFDF2F8)), // Pink 50
          ],
        ),
      ],
    );
  }
}

class InfoChip extends StatelessWidget {
  final String text;
  final Color color;

  const InfoChip({required this.text, required this.color, super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8.0),
        border: Border.all(color: Colors.grey.shade200),
      ),
      alignment: Alignment.centerLeft,
      child: Text(
        text,
        style: const TextStyle(fontSize: 12, color: Colors.black87),
      ),
    );
  }
}