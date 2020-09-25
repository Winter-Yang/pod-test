#!/usr/bin/env ruby
require "optparse"
require 'pathname'

pn = Pathname.new(__FILE__).realpath;
$dir = File.dirname(pn);
cocoapodsPath=""
if ($dir.include? '/Users') & ($dir.include? '/Desktop')
    limit = $dir.split("/Desktop");
    cocoapodsPath = limit[0];
else
    puts "不在用户目录下";
end

zybspecPath = "#{cocoapodsPath}/.cocoapods/repos/ZYBSpecs";
zybspecAFPath = "#{cocoapodsPath}/.cocoapods/repos/afpai-zybspecs";

if File::exist?(zybspecPath)
    puts "ZYBSpecs 存在 #{zybspecPath}"
    $zybSpecName = "ZYBSpecs"
elsif File::exist?(zybspecAFPath)
    puts "afpai-zybspecs  存在 #{zybspecAFPath}"
    $zybSpecName = "afpai-zybspecs"
else
    puts "文件不存在,是否需要安装cocoapods"
end


$zybSpecName = "afpai-zybspecs"
$sources="--sources=git@git.afpai.com:native/ZYBSpecs.git,https://github.com/CocoaPods/Specs.git"

$options = {:specs => $zybSpecName,
			:isFix => false,
			:uselibraries => '--use-libraries',
			:allowwarnings => '--allow-warnings'}


class PodspecObject
        attr_accessor :specName, :specPath, :rootPath
        
        def initialize(*params)
        	if params != nil
        		@specName = params.at(0)
            	@specPath = params.at(1)
            	@rootPath = params.at(2)
        	end
        end
end

$specObject = PodspecObject.new(nil)

option_parser = OptionParser.new do |opts|

	opts.banner = "Usage:
 
 $ \033[40m\033[32mruby test.rb  -p Login.podspec -t 0.0.4\033[0m
 
   here is help messages of the command line tool."
	
	opts.separator ""
	opts.separator "Common Options:"
	opts.on( "-p NAME", "--podspec name", "Podspec name or path") do |value|
		$options[:podspec] = value
	end
	opts.on( "-t TAG", "--tag Tag", "New Version or git tag" ) do |value|
		$options[:tag] = value
	end
	opts.on( "-b BRANCH", "--branch Branch", "The new tag For branch" ) do |value|
		$options[:branch] = value
	end
	opts.on( "-s NAME", "--specs Name", "Local specs name,default ZYBSpecs" ) do |value|
		$options[:specs] = value
	end
	opts.on( "-l", "--use-libraries", "Pod lib lint / pod repo push default --use-libraries" ) do
		$options[:uselibraries] = "--use-libraries"
	end
	opts.on( "-w", "--allow-warnings", "Pod lib lint / pod repo push default --allow-warnings" ) do
		$options[:allowwarnings] = "--allow-warnings"
	end
	opts.on( "-u", "--repo-update", " Allow pod repo update " ) do
		$options[:repoupdate] = true
	end

	opts.on( "-h", "--help", "Show this message." ) do
		puts opts
		exit
	end
	
end.parse!

# 日志模块
module Logger
    def Logger.print(errType, msg) 
    	if  errType != nil && msg!=nil
        	puts " \033[40m\033[36m[#{errType}] #{msg}\033[0m\n"
            if errType == 'ERROR'
            	puts " \033[40m\033[31m[Usage: Use --help for more infomation ]\033[0m\n"
                exit
            end
        end
    end
end


# 取RCTag模块
module RCTag
	$specsName = $options[:specs]
    $cocoapodsRepoPath = '%s/.cocoapods/repos' % ENV['HOME']                             # cocoapods本地仓库路径
    $path = "#{$cocoapodsRepoPath}/#{$specsName}"                             # 本地podspec目录路径
    
    def RCTag.getRCVersion(libName)
        getDirContent($path, libName)
    end
    
    def RCTag.getDirContent(path, matchName)
        fileList = Array.new
        Dir.entries(path).each do |subDir|
            if subDir == matchName
                # subPath = "zybspecs/BaseLib"
                subPath = "#{path}/#{subDir}"
                fileList.concat(getFileList(subPath))
                fileList = fileList.sort{ |a, b|
                    rcVersionObjA = RcVersionObj.new(a, subPath)
                    rcVersionObjB = RcVersionObj.new(b, subPath)
                    rcVersionObjA.getComparisionResultWith(rcVersionObjB)
                }
                Logger.print("VersionLists","版本列表====#{fileList}")

            end
        end
        if fileList.size >0
        	return fileList.last
        else
        	return "0.0.0"
        end
        
    end
    
    # 取得部门lib目录中所有的rc目录名称列表
    def RCTag.getFileList(dirName)
        fileList = Array.new
        Dir.entries(dirName).each do |file|
            if file.match('\.[0-9]+') != nil
                fileList.push(file)
            end
        end
        return fileList
    end

    class RcVersionObj
        # 初始化方法
        def initialize(rcStr, path)
            @lastMTime = File.new("#{path}/#{rcStr}").mtime.to_i
            version = rcStr
            @versionArray = Array.new
            version.split('.').each { |e| @versionArray.push(e.to_i) }
            @versionArray.push(version.to_i)
        end
        
        # 获得rc文件最后修改时间
        def getLastModifyTime
            @lastMTime
        end
        
        # 获得对应的版本号
        # 参数 0:base version 1:alpha version 2:beta version 3:rc tag
        def getVersionAtIndex(index)
            @versionArray.at(index)
        end
        
        # 两个版本号比较结果
        # 返回值 1:a小于b -1:a大于b 0:a等于b
        def getComparisionResultWith(rcVersionObj)
            start = 0
            value = sortByModifyTime(rcVersionObj)
            while value == 0 && start < @versionArray.count do
                value = sort(rcVersionObj, start)
                start += 1
            end
            return value
        end
        
        # 两个rc文件的最后修改时间比较结果
        def sortByModifyTime(rcVersionObj)
            @lastMTime <=> rcVersionObj.getLastModifyTime
        end
            
        # 两个版本号的比较结果
        def sort(rcVersionObj, index)
            @versionArray.at(index) <=> rcVersionObj.getVersionAtIndex(index)
        end
            
        protected :sort, :getVersionAtIndex, :sortByModifyTime
    end
end   


#检测新tag 优先使用用户输入Tag，
module TagManager
	
    def TagManager.newTag

		podname = $specObject.specName.clone.split(".")[0]
		# delete! ".podspec"
    	lastVersion =RCTag.getRCVersion(podname)
    	Logger.print("REPO","#{podname}当前最新版本 : #{lastVersion}")

    	if $options[:tag] == nil;
        	newversion = TagManager.newVersion(lastVersion)
    	else

	    	userVersion =$options[:tag];
	        # usercacheVersion = userVersion.clone.delete! '.'
	        # lastcacheVersion = lastVersion.clone.delete! '.'
	        # if usercacheVersion.to_i >= lastcacheVersion.to_i  
	        # 	newversion = userVersion;
	        # 	Logger.print("INFO","#{podname}新版本号 : #{userVersion}")
	        # else
	        # 	newversion = TagManager.newVersion(lastVersion)
	        # end
	        newversion = userVersion;
    	end

        return newversion
    end


    def TagManager.newVersion(version)
    	podname = $specObject.specName.clone.split(".")[0]
    	#用户输入小于当前版本号或者没有输入版本号，则自动+1,需要打tag
    	lastVersion = version.clone
    	lastVersion = lastVersion.delete! '.'
        versionNumer_ca = "%03d" % (lastVersion.to_i+1)
        newversion_ca = versionNumer_ca.to_s
        newversion_ca.gsub!(/./){|s| s[0]+'.'}.chop!
        Logger.print("REPO","#{podname}新版本号 : #{newversion_ca}")
    	return newversion_ca
    end
end

module Repo

	
	@uselibraries = $options[:uselibraries];
	@allowwarnings = $options[:allowwarnings];
	@repoSpecs = $options[:specs];
	def Repo.specsUpdate
		Logger.print("REPO","正在更新repo，请等待")
		result=system('pod repo update')
		Logger.print("REPO","REPO更新完成")
		return result
	end

	def Repo.lint
		
		Logger.print("REPO","开始验证podspec")
		cmdcd = "cd #{$specObject.rootPath}"
		cmdpoblib = "pod lib lint --verbose #{@uselibraries} #{@allowwarnings}  #{$sources} --silent"
	    result = system("#{cmdcd};#{cmdpoblib}")
        if result == false
            Logger.print("ERROR","podspec验证失败，请检查代码或者podspec文件")
            exit       
        end
        Logger.print("REPO","podspec验证成功")
	end

	def Repo.push
		cmdcd = "cd #{$specObject.rootPath}"
		Logger.print("REPO","开始上传podspec至私有库 \n pod repo push --verbose --no-ansi #{@repoSpecs} #{$specObject.specName} #{@uselibraries} #{@allowwarnings} #{$sources}")

		cmdpobpush = "pod repo push --verbose --no-ansi #{@repoSpecs} #{$specObject.specName} #{@uselibraries} #{@allowwarnings} #{$sources}"
		Logger.print("REPO","开始上传podspec至私有库")
	    result = system("#{cmdcd};#{cmdpobpush}")
        if result == false
            Logger.print("ERROR","上传podspec失败，请检查代码或者podspec文件或ruby指定")
            exit       
        end
		Logger.print("REPO","上传podspec成功，执行pod search 进行查询")
		
		system("")

	end


	
end

module GitManager
	def GitManager.AddTag

		cmdbranch = "git symbolic-ref --short -q HEA"
		if $options[:branch] != nil
	    	cmdbranch = $options[:branch]
		end
		Logger.print("GitManager","当前分支 : #{cmdbranch}")
		new_tag = TagManager.newTag;
		cmd_cd = "cd #{$specObject.rootPath}"
		cmd_add = 'git add .'
		#检测文件版本是否匹配
		isModifyFile = FileManager.fileVersionCheck(new_tag)
		if isModifyFile == true
            Logger.print("GitManager","Tag Commit")
			cmd_commit = 'git commit -m "' + "修改podspec文件版本号#{new_tag}" + '"'
			cmd_push = 'git push'
			result = system("#{cmd_cd};#{cmd_add};#{cmd_commit};#{cmd_push}")
		end
		
	
	    commit_desc = "Tag:version_" + new_tag
		cmd_tag = 'git tag -m " add:tag ' + new_tag + '" ' + new_tag
		cmd_pushtag = 'git push --tags'

		result = false
		Logger.print("GitManager","Tag Creat: #{new_tag}")
		cmd_detag = 'git tag -d ' + new_tag
		cmd_pushde = 'git push origin :refs/tags/' +  new_tag
		system("#{cmd_cd};#{cmd_add};#{cmd_detag};#{cmd_pushde};#{cmd_tag};#{cmd_pushtag}")
	end
	
end

module FileManager
	def FileManager.checkPodspec
		podspec = $options[:podspec]
		podspecname = ""
		rootPath = ""
		if podspec == nil
			Logger.print("FileManager","podspec : 请输入podspec文件名称")
			exit
		end
		if podspec.include? "/"
		   	Logger.print("FileManager","PodspecPath : #{podspec}")
		    #传进来的是一个路径
		   	path = podspec.clone
		   	isexist = File.exist?(path)
		  	if isexist == true
		   		podspecname = File.basename(path)
		   		rootPath = File::dirname(path)
		   		Logger.print("FileManager","PodspecName : #{podspecname}")
		   	else
		   	    Logger.print("ERROR","PodspecPath : podspec文件路径不存在")
		   		exit
		   	end
		else
			#传进来的是一个名字，此时必须在当前文件目录下
		   	podspecname = podspec.clone
		   	rootPath = Dir.pwd
		end

		tmpArray = Array.new
        tmpArray.push(podspecname)
        tmpArray.push(File.join(rootPath,podspecname))
        tmpArray.push(rootPath)
		$specObject = PodspecObject.new(*tmpArray)

	end

	def FileManager.fileVersionCheck(value)

		new_version = value.clone.to_s
		file_version = ""
		find_version_flag = false
		isModifyFile = false

		IO.foreach($specObject.specPath){|line| 
			
			if line.include? ".version"
				if find_version_flag == false
					file_version = line.split('=')[1]
					file_version = file_version.gsub("'", "").gsub(" ", "").gsub("\n", "")
					new_version = new_version.gsub(" ", "")
					if new_version != file_version
						isModifyFile = true
					end
					find_version_flag = true
				end
				
			end
		}

		if isModifyFile == true
			Logger.print("FileManager","修改#{$specObject.specName}版本号 #{file_version}==>#{new_version}")
			cmd_sed= "sed -i -e 's/#{file_version}/#{new_version}/' #{$specObject.specPath}"
			system("#{cmd_sed}")
		end
		return isModifyFile
	end
end


Logger.print("INFO","开始进程，请稍后")
if $options[:repoupdate] == true
   result =	Repo.specsUpdate
   if result == false
   		Logger.print("ERROR","REPO更新失败，请检查 ！！！！")
   		exit
   end
end

#File基础操作,包括不限于(校验、版本生成)
FileManager.checkPodspec
#Git相关
GitManager.AddTag
#Pod相关 由于库暂时很多相互依赖，无法校验，此处直接上传
#Repo.lint
Repo.push



