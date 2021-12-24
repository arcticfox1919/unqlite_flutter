#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint unqlite_flutter.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'unqlite_flutter'
  s.version          = '0.0.1'
  s.summary          = 'A new Flutter plugin.'
  s.description      = <<-DESC
A new Flutter plugin.
                       DESC
  s.homepage         = 'https://github.com/arcticfox1919/unqlite_flutter'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'arcticfox' => 'flutterdev@88.com'}
  s.source           = { :path => '.' }
  s.source_files = 'Classes/**/*'
  s.public_header_files = 'Classes/**/*.h'
  s.dependency 'Flutter'
  s.platform = :ios, '9.0'
  s.vendored_frameworks = 'unqlite.framework'
  s.static_framework = true 
  # Flutter.framework does not contain a i386 slice.
  #s.vendored_libraries = 'libunqlite.a'
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
end
