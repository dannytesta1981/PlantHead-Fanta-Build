import 'dart:async';
class RuntimeFixture {
 static late Uri start;
 static bool forwardStop=false;
 static int stops=0;
 static Completer<void>? hold;
 static bool held=false;
}
