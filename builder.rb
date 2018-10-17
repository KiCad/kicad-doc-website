
require 'fileutils'
require 'yaml'
require 'asciidoctor'
require 'tempfile'

def process_compiled_docs
	skip_folders = [
					'CMakeFiles',
					'gui_translation_howto',
					'.',
					'..'
				]


	skip_files = [
		'cmake_install.cmake',
		'Makefile'
	]

	seenLangs = []

	guides = {}

	Dir.foreach('./src') do |guideEntry|
		next if skip_folders.include?guideEntry

		next if !File.directory? File.join('./src', guideEntry)
		# do work on real items


		print "Processing " + guideEntry + "\n"

		Dir.foreach(File.join('./src', guideEntry)) do |langEntry|
			next if skip_folders.include?langEntry
			next if !File.directory? File.join('./src', guideEntry, langEntry)

			seenLangs.push(langEntry)

			if guides[langEntry].nil?
				guides[langEntry] = []
			end

			mainDocPath = File.join('./src', guideEntry, langEntry, guideEntry+'.adoc')

			#load the asciidoc file...to get the translated title mainly
			doc = Asciidoctor.load_file mainDocPath


			image_path = File.join('img','guide-icons',guideEntry+'.png')

			if !File.exist?(image_path)
				image_path = ''
			end
			
			FileUtils.mkdir_p(File.join('./', langEntry, guideEntry)) unless Dir.exist?(File.join('./', langEntry, guideEntry))
			FileUtils.cp_r(File.join('./src', guideEntry, langEntry)+'/.', File.join('./', langEntry, guideEntry))

			main_adoc_path = File.join('./', langEntry, guideEntry,guideEntry+'.adoc')
			#time to mangle files!

			_update_main_adoc(main_adoc_path,doc.doctitle,langEntry)

			epub_path = File.join(langEntry, guideEntry,guideEntry+'.epub')
			if !File.exist?(epub_path)
				epub_path = ''
			end

			pdf_path = File.join(langEntry, guideEntry,guideEntry+'.pdf')
			if !File.exist?(pdf_path)
				pdf_path = ''
			end

			guides[langEntry].push({
									"title" => doc.doctitle, 
									"url" => "/%s/%s.html" % [guideEntry,guideEntry],
									"image" => image_path,
									"description" => "",
									"pdf" => pdf_path,
									"epub" => epub_path
									})
			
		end
	end
	File.open("_data/generated_guides.yml", "w") { |file| file.write(guides.to_yaml) }


	# Lets create the selectable language list
	# seems silly but hey, just in case one disappears or appears, we need a friendly translation for the dropdown
	# and this enforces we have one
	seenLangs = seenLangs.uniq
	langDefinitions = YAML.load_file("_data/language_definitions.yml")
	outputLangHash = {}

	langDefinitions.each do | lang, definition | 
		if seenLangs.include?(lang)
			outputLangHash[lang] = definition
		else
			$stderr.puts "Unable to find definition of language '%s' in language_definitions.yml" % [lang]
		end
	end

	File.open("_data/generated_languages.yml", "w") { |file| file.write(outputLangHash.to_yaml) }


	indexTemplate = File.read("_templates/index.html")
	seenLangs.each do | lang |
		langIndex = indexTemplate.gsub(/%%LANG%%/, lang)
	
		File.open(File.join("./", lang, "index.html"), "w") {|file| file.puts langIndex }
	end
end

def _update_main_adoc(adocPath, title, lang)
	
	headerTemplate = File.read("_templates/adoc_header.txt")
	headerTemplate = headerTemplate.gsub(/%%TITLE%%/, title)
	headerTemplate = headerTemplate.gsub(/%%LANG%%/, lang)
	Tempfile.open File.basename(adocPath) do |tempfile|
		# prepend data to tempfile
		tempfile << headerTemplate
		tempfile.write "\n"

		File.open(adocPath, 'r+') do |file|
		  # append original data to tempfile
		  tempfile << file.read
		  # reset file positions
		  file.pos = tempfile.pos = 0
		  # copy all data back to original file
		  file << tempfile.read
		end
	end
end