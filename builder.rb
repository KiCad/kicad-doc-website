
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

	versionsDefined = YAML.load_file("_source/_data/versions.yml")

	versionsDefined.each do |version, versionInfo|
		next if !File.directory? File.join('./kicad-doc-built', version)
		
		if guides[version].nil?
			guides[version] = {}
		end


		Dir.foreach(File.join('./kicad-doc-built', version)) do |guideEntry|
			next if skip_folders.include?guideEntry

			next if !File.directory? File.join('./kicad-doc-built', version, guideEntry)
			# do work on real items


			print "Processing " + guideEntry + "\n"

			Dir.foreach(File.join('./kicad-doc-built', version, guideEntry)) do |langEntry|
				next if skip_folders.include?langEntry
				next if !File.directory? File.join('./kicad-doc-built', version, guideEntry, langEntry)

				seenLangs.push(langEntry)

				if guides[version][langEntry].nil?
					guides[version][langEntry] = []
				end

				# this is the "index" adoc file that includes all of them
				mainDocPath = File.join('./kicad-doc-built', version, guideEntry, langEntry, guideEntry+'.adoc')

				#load the asciidoc file...to get the translated title mainly
				doc = Asciidoctor.load_file mainDocPath


				image_path = File.join('img','guide-icons',guideEntry+'.png')

				if !File.exist?(image_path)
					image_path = ''
				end
				
				FileUtils.mkdir_p(File.join('./_source/', version,  langEntry, guideEntry)) unless Dir.exist?(File.join('./_source/', version, langEntry, guideEntry))


				guide_files = Dir.glob(File.join('./kicad-doc-built', version, guideEntry, langEntry) + "/*").select{ |x| File.file? x }
				guide_image_files = Dir.glob(File.join('./kicad-doc-built', version, guideEntry, langEntry) + "/images/*").select{ |x| File.file? x }
				guide_icon_files = Dir.glob(File.join('./kicad-doc-built', version, guideEntry, langEntry) + "/images/icons/*").select{ |x| File.file? x }
				guide_lang_image_files = Dir.glob(File.join('./kicad-doc-built', version, guideEntry, langEntry) + "/images/"+langEntry+"/*").select{ |x| File.file? x }

				FileUtils.cp(guide_files, File.join('./_source/', version, langEntry, guideEntry))

				FileUtils.mkdir_p(File.join('./_source/', version, langEntry, guideEntry, 'images', langEntry))
				FileUtils.mkdir_p(File.join('./_source/', version, langEntry, guideEntry, 'images', 'icons'))
				FileUtils.cp(guide_image_files, File.join('./_source/', version, langEntry, guideEntry, 'images'))
				FileUtils.cp(guide_icon_files, File.join('./_source/', version, langEntry, guideEntry, 'images','icons'))
				FileUtils.cp(guide_lang_image_files, File.join('./_source/', version, langEntry, guideEntry, 'images', langEntry))

				main_adoc_path = File.join('./_source/', version, langEntry, guideEntry,guideEntry+'.adoc')
				#time to mangle files!

				_update_main_adoc(main_adoc_path,doc.doctitle,langEntry, version)

				epub_path = File.join("./_source/", version, langEntry, guideEntry,guideEntry+'.epub')
				if !File.exist?(epub_path)
					epub_path = ''
				end

				pdf_path = File.join("./_source/", version, langEntry, guideEntry,guideEntry+'.pdf')
				if !File.exist?(pdf_path)
					pdf_path = ''
				end

				guides[version][langEntry].push({
										"title" => doc.doctitle, 
										"url" => "/%s/%s.html" % [guideEntry,guideEntry],
										"image" => image_path,
										"description" => "",
										"pdf" => pdf_path,
										"epub" => epub_path
										})
				
			end
		end
		File.open("_source/_data/generated_guides.yml", "w") { |file| file.write(guides.to_yaml) }


		# Lets create the selectable language list
		# seems silly but hey, just in case one disappears or appears, we need a friendly translation for the dropdown
		# and this enforces we have one
		seenLangs = seenLangs.uniq
		langDefinitions = YAML.load_file("_source/_data/language_definitions.yml")
		outputLangHash = {}

		langDefinitions.each do | lang, definition | 
			if seenLangs.include?(lang)
				outputLangHash[lang] = definition
			else
				$stderr.puts "Unable to find definition of language '%s' in language_definitions.yml" % [lang]
			end
		end

		File.open("_source/_data/generated_languages.yml", "w") { |file| file.write(outputLangHash.to_yaml) }


		indexTemplate = File.read("_source/_templates/index.html")
		seenLangs.each do | lang |
			#write the language specific index
			_write_index_file(File.join("./_source/", version, lang, "index.html"), "Home", lang, version)
		end
		
		# write the "version index"
		_write_index_file(File.join("./_source/", version, "index.html"), "Home", "en", version)
	end

	# Generate the main/true index which is really just the english one
	_write_index_file("./_source/index.html", "Home", "en", "5.0.2")
end

def _write_index_file(path, title, lang, version)
	indexTemplate = File.read("_source/_templates/index.html")
	
	print "Writing index for " + lang + "\n"
	langIndex = indexTemplate
	langIndex = langIndex.gsub(/%%LANG%%/, lang)
	langIndex = langIndex.gsub(/%%VERSION%%/, version)

	File.open(path, "w") {|file| file.puts langIndex }
end

def _update_main_adoc(adocPath, title, lang, version)
	
	headerTemplate = File.read("_source/_templates/adoc_header.txt")
	headerTemplate = headerTemplate.gsub(/%%TITLE%%/, title)
	headerTemplate = headerTemplate.gsub(/%%LANG%%/, lang)
	headerTemplate = headerTemplate.gsub(/%%VERSION%%/, version)
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