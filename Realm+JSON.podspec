Pod::Spec.new do |s|
  s.name     = 'Realm+JSON'
  s.version  = '0.1.8'
  s.ios.deployment_target   = '6.0'
  s.license  = { :type => 'MIT', :file => 'LICENSE' }
  s.summary  = 'A concise Mantle-like way of working with Realm and JSON.'
  s.homepage = 'https://github.com/matthewcheok/Realm-JSON'
  s.author   = { 'Matthew Cheok' => 'cheok.jz@gmail.com' }
  s.requires_arc = true
  s.source   = {
    :git => 'https://github.com/matthewcheok/Realm-JSON.git',
    :branch => 'master',
    :tag => s.version.to_s
  }
  s.source_files = 'Realm+JSON/*.{h,m}'
  s.public_header_files = 'Realm+JSON/*.h'

  s.dependency 'Realm', '~> 0.85.0'
end
