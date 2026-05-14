require 'xcodeproj'
project_path = 'The Friendly Fitness Companion V2.xcodeproj'
project = Xcodeproj::Project.open(project_path)
target = project.targets.first
group = project.main_group.find_subpath('The Friendly Fitness Companion V2/Views', true)
file_ref = group.new_file('FastingHistoryView.swift')
target.source_build_phase.add_file_reference(file_ref)
project.save
