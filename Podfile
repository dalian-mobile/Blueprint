platform :ios, '12.0'
inhibit_all_warnings!
use_frameworks!

project 'SampleApp/SampleApp.xcodeproj'

def blueprint_pods
  pod 'BlueprintUI', :path => './BlueprintUI.podspec', :testspecs => ['Tests'] 
  pod 'BlueprintUICommonControls', :path => './BlueprintUICommonControls.podspec', :testspecs => ['SnapshotTests'] 
end

target 'SampleApp' do
  blueprint_pods
end

target 'Tutorial 1' do
  blueprint_pods
end

target 'Tutorial 1 (Completed)' do
  blueprint_pods
end

target 'Tutorial 2' do
  blueprint_pods
end

target 'Tutorial 2 (Completed)' do
  blueprint_pods
end
