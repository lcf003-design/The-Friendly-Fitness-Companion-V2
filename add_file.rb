require 'xcodeproj'
project_path = 'The Friendly Fitness Companion V2.xcodeproj'
project = Xcodeproj::Project.open(project_path)
target = project.targets.first

# Add ComparisonCardExporter
services_group = project.main_group.find_subpath('The Friendly Fitness Companion V2/Services', true)
file_ref_exporter = services_group.new_file('ComparisonCardExporter.swift')
target.source_build_phase.add_file_reference(file_ref_exporter)

# Add CameraCaptureView
views_group = project.main_group.find_subpath('The Friendly Fitness Companion V2/Views', true)
file_ref_camera = views_group.new_file('CameraCaptureView.swift')
target.source_build_phase.add_file_reference(file_ref_camera)

project.save
print "Successfully registered ComparisonCardExporter.swift and CameraCaptureView.swift in Xcode project."
