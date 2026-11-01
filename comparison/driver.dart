import 'dart:io';
import 'package:integration_test/integration_test_driver_extended.dart';
Future<void> main()async{
 await integrationDriver(writeResponseOnFailure:true,onScreenshot:(name,bytes,[args])async{await Directory('comparison-results').create(recursive:true);await File('comparison-results/$name.png').writeAsBytes(bytes);return true;},responseDataCallback:(data)async{final safe=Map<String,dynamic>.from(data??{});safe.remove('screenshots');await writeResponseData(safe,testOutputFilename:'result',destinationDirectory:'comparison-results');});
}
