#
# Run `pod lib lint ym_easy_pdf_viewer.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'ym_easy_pdf_viewer'
  s.version          = '1.0.0'
  s.summary          = 'A Flutter PDF viewer for Android and iOS.'
  s.description      = <<-DESC
  A Flutter PDF viewer with asset, file, URL, paging, zoom, and download
  progress support.
                       DESC
  s.homepage         = 'https://github.com/yashmanghnani/ym_easy_pdf_viewer'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Yash Manghnani' => 'https://github.com/yashmanghnani' }
  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*'
  s.dependency       'Flutter'
  s.platform         = :ios, '15.0'

  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386'
  }
  s.swift_version = '5.0'
end
