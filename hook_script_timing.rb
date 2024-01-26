require 'xcodeproj'

# 定义用于标识计时代码的文本常量
HOOK_HEADER_MARKER = "[time] Starting phase"
HOOK_FOOTER_MARKER = "[time] Phase took"

# 为指定的 Xcode 项目添加计时钩子
def hook_project(project_path)
  project = Xcodeproj::Project.open(project_path)
  
  # 遍历项目中的所有目标
  project.targets.each do |target|
    # 遍历目标中的所有构建阶段
    target.build_phases.each do |phase|
      # 针对 Shell 脚本构建阶段
      if phase.is_a?(Xcodeproj::Project::Object::PBXShellScriptBuildPhase)
        # 防止重复添加计时代码
        unless phase.shell_script.include?(HOOK_HEADER_MARKER) && phase.shell_script.include?(HOOK_FOOTER_MARKER)
        
          # 生成需要插入的开始计时脚本
          hook_header = <<-SCRIPT
start_time=\$(date +%s)
echo "#{HOOK_HEADER_MARKER} #{phase.display_name}"
SCRIPT
          
          # 生成需要插入的结束计时和耗时输出脚本
          hook_footer = <<-SCRIPT
end_time=\$(date +%s)
duration=\$((end_time - start_time))
echo "#{HOOK_FOOTER_MARKER} #{phase.display_name} took \$duration seconds to complete."
SCRIPT
          
          # 在脚本的头部和尾部添加计时代码
          phase.shell_script.prepend(hook_header)
          phase.shell_script << hook_footer
        end
      end
    end
  end
  
  # 保存修改后的项目
  project.save
  puts "已向 #{project_path} 添加计时钩子"
end

# 从指定的 Xcode 项目中清理计时钩子
def clean_hook_project(project_path)
  project = Xcodeproj::Project.open(project_path)

  # 遍历项目的所有目标
  project.targets.each do |target|
    # 遍历目标中的所有构建阶段
    target.build_phases.each do |phase|
      if phase.is_a?(Xcodeproj::Project::Object::PBXShellScriptBuildPhase)
        # 删除已存在的计时代码
        phase.shell_script.gsub!(/#{Regexp.escape(HOOK_HEADER_MARKER)}.+\n/, '')
        phase.shell_script.gsub!(/#{Regexp.escape(HOOK_FOOTER_MARKER)}.+\n/, '')
      end
    end
  end

  # 保存修改后的项目
  project.save
  puts "已从 #{project_path} 清理计时钩子"
end

# 查找当前目录及子目录下所有 Xcode 项目文件(.xcodeproj)，并执行操作（添加/清理钩子）
def find_and_operate(operation)
  start_time = Time.now
  
  # 查找所有的 .xcodeproj 文件
  Dir.glob(File.join(Dir.pwd, '**', '*.xcodeproj')).each do |xcodeproj_dir|
    puts "正在处理 #{xcodeproj_dir}"
    send(operation, xcodeproj_dir) # 执行相应的操作（添加或清理）
  end
  
  puts "操作完成，耗时 #{Time.now - start_time}s"
end

# 处理命令行参数
case ARGV[0]
when '-cleanhook'
  find_and_operate(:clean_hook_project) # 清理项目中的计时钩子
when '-hook'
  find_and_operate(:hook_project) # 为项目添加计时钩子
else
  # 如果参数不符合预期，输出错误信息
  puts "无效参数。使用 '-hook' 来添加钩子，或 '-cleanhook' 来移除钩子。"
end
