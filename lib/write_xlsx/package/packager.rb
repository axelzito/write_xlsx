# -*- coding: utf-8 -*-
require 'write_xlsx/package/xml_writer_simple'
require 'write_xlsx/utility'
require 'write_xlsx/package/app'
require 'write_xlsx/package/comments'
require 'write_xlsx/package/content_types'
require 'write_xlsx/package/core'
require 'write_xlsx/package/custom'
require 'write_xlsx/package/metadata'
require 'write_xlsx/package/relationships'
require 'write_xlsx/package/shared_strings'
require 'write_xlsx/package/styles'
require 'write_xlsx/package/table'
require 'write_xlsx/package/theme'
require 'write_xlsx/package/vml'

module Writexlsx
  module Package
    class Packager

      include Writexlsx::Utility

      def initialize(workbook)
        @workbook     = workbook
        @package_dir  = ''
        @table_count  = @workbook.worksheets.tables_count
        @named_ranges = []
      end

      def set_package_dir(package_dir)
        @package_dir = package_dir
      end

      #
      # Write the xml files that make up the XLXS OPC package.
      #
      def create_package
        write_worksheet_files
        write_chartsheet_files
        write_workbook_file
        write_chart_files
        write_drawing_files
        write_vml_files
        write_comment_files
        write_table_files
        write_shared_strings_file
        write_app_file
        write_core_file
        write_custom_file
        write_content_types_file
        write_styles_file
        write_theme_file
        write_root_rels_file
        write_workbook_rels_file
        write_worksheet_rels_files
        write_chartsheet_rels_files
        write_drawing_rels_files
        add_image_files
        add_vba_project
        write_metadata_file
      end

      private

      #
      # Write the workbook.xml file.
      #
      def write_workbook_file
        FileUtils.mkdir_p("#{@package_dir}/xl")

        @workbook.set_xml_writer("#{@package_dir}/xl/workbook.xml")
        @workbook.assemble_xml_file
      end

      #
      # Write the worksheet files.
      #
      def write_worksheet_files
        @workbook.worksheets.write_worksheet_files(@package_dir)
      end

      #
      def write_chartsheet_files
        @workbook.worksheets.write_chartsheet_files(@package_dir)
      end

      #
      # Write the chart files.
      #
      def write_chart_files
        write_chart_or_drawing_files(@workbook.charts, 'chart')
      end

      #
      # Write the drawing files.
      #
      def write_drawing_files
        write_chart_or_drawing_files(@workbook.drawings, 'drawing')
      end

      def write_chart_or_drawing_files(objects, filename)
        dir = "#{@package_dir}/xl/#{filename}s"

        objects.each_with_index do |object, index|
          FileUtils.mkdir_p(dir)
          object.set_xml_writer("#{dir}/#{filename}#{index+1}.xml")
          object.assemble_xml_file
        end
      end

      #
      # Write the comment VML files.
      #
      def write_vml_files
        @workbook.worksheets.write_vml_files(@package_dir)
      end

      #
      # Write the comment files.
      #
      def write_comment_files
        @workbook.worksheets.write_comment_files(@package_dir)
      end

      #
      # Write the sharedStrings.xml file.
      #
      def write_shared_strings_file
        sst  = @workbook.shared_strings

        FileUtils.mkdir_p("#{@package_dir}/xl")

        return if @workbook.shared_strings_empty?

        sst.set_xml_writer("#{@package_dir}/xl/sharedStrings.xml")
        sst.assemble_xml_file
      end

      #
      # Write the app.xml file.
      #
      def write_app_file
        app = Package::App.new(@workbook)

        # Add the Worksheet heading pairs.
        app.add_worksheet_heading_pairs
        # Add the Chartsheet heading pairs.
        app.add_chartsheet_heading_pairs

        # Add the Worksheet parts.
        app.add_worksheet_part_names
        # Add the Chartsheet parts.
        app.add_chartsheet_part_names
        # Add the Named Range heading pairs.
        app.add_named_range_heading_pairs
        # Add the Named Ranges parts.
        app.add_named_ranges_parts

        app.set_properties(@workbook.doc_properties)
        app.doc_security = @workbook.read_only

        FileUtils.mkdir_p("#{@package_dir}/docProps")
        app.set_xml_writer("#{@package_dir}/docProps/app.xml")
        app.assemble_xml_file
      end

      #
      # Write the core.xml file.
      #
      def write_core_file
        core       = Package::Core.new

        FileUtils.mkdir_p("#{@package_dir}/docProps")

        core.set_properties(@workbook.doc_properties)
        core.set_xml_writer("#{@package_dir}/docProps/core.xml")
        core.assemble_xml_file
      end

      #
      # Write the metadata.xml file.
      #
      def write_metadata_file
        metadata = Package::Metadata.new(@workbook)

        return unless @workbook.has_metadata?

        FileUtils.mkdir_p("#{@package_dir}/xl")

        metadata.set_xml_writer( "#{@package_dir}/xl/metadata.xml")
        metadata.assemble_xml_file
      end

      #
      # Write the custom.xml file.
      #
      def write_custom_file
        properties = @workbook.custom_properties
        custom     = Package::Custom.new

        return if properties.empty?

        FileUtils.mkdir_p("#{@package_dir}/docProps")

        custom.set_properties(properties)
        custom.set_xml_writer("#{@package_dir}/docProps/custom.xml")
        custom.assemble_xml_file
      end

      #
      # Write the ContentTypes.xml file.
      #
      def write_content_types_file
        content = Package::ContentTypes.new(@workbook)

        content.add_image_types
        content.add_worksheet_names
        content.add_chartsheet_names
        content.add_chart_names
        content.add_drawing_names
        content.add_vml_name if @workbook.num_vml_files > 0
        content.add_table_names(@table_count)
        content.add_comment_names
        # Add the sharedString rel if there is string data in the workbook.
        content.add_shared_strings unless @workbook.shared_strings_empty?
        # Add vbaProject if present.
        content.add_vba_project if @workbook.vba_project
        # Add the custom properties if present.
        content.add_custom_properties unless @workbook.custom_properties.empty?
        # Add the metadata file if present.
        content.add_metadata if @workbook.has_metadata?

        content.set_xml_writer("#{@package_dir}/[Content_Types].xml")
        content.assemble_xml_file
      end

      #
      # Write the style xml file.
      #
      def write_styles_file
        dir              = "#{@package_dir}/xl"

        rels = Package::Styles.new

        FileUtils.mkdir_p(dir)

        rels.set_style_properties(*@workbook.style_properties)

        rels.set_xml_writer("#{dir}/styles.xml" )
        rels.assemble_xml_file
      end

      #
      # Write the style xml file.
      #
      def write_theme_file
        rels = Package::Theme.new

        FileUtils.mkdir_p("#{@package_dir}/xl/theme")

        rels.set_xml_writer("#{@package_dir}/xl/theme/theme1.xml")
        rels.assemble_xml_file
      end

      #
      # Write the table files.
      #
      def write_table_files
        @workbook.worksheets.write_table_files(@package_dir)
      end

      #
      # Write the _rels/.rels xml file.
      #
      def write_root_rels_file
        rels = Package::Relationships.new

        FileUtils.mkdir_p("#{@package_dir}/_rels")

        rels.add_document_relationship('/officeDocument', 'xl/workbook.xml')

        rels.add_package_relationship('/metadata/core-properties',
            'docProps/core.xml')

        rels.add_document_relationship('/extended-properties', 'docProps/app.xml')

        unless @workbook.custom_properties.empty?
          rels.add_document_relationship('/custom-properties', 'docProps/custom.xml')
        end
        rels.set_xml_writer("#{@package_dir}/_rels/.rels" )
        rels.assemble_xml_file
      end

      #
      # Write the _rels/.rels xml file.
      #
      def write_workbook_rels_file
        rels = Package::Relationships.new

        FileUtils.mkdir_p("#{@package_dir}/xl/_rels")

        worksheet_index  = 1
        chartsheet_index = 1

        @workbook.worksheets.each do |worksheet|
          if worksheet.is_chartsheet?
            rels.add_document_relationship('/chartsheet', "chartsheets/sheet#{chartsheet_index}.xml")
            chartsheet_index += 1
          else
            rels.add_document_relationship( '/worksheet', "worksheets/sheet#{worksheet_index}.xml")
            worksheet_index += 1
          end
        end

        rels.add_document_relationship('/theme',  'theme/theme1.xml')
        rels.add_document_relationship('/styles', 'styles.xml')

        # Add the sharedString rel if there is string data in the workbook.
        rels.add_document_relationship('/sharedStrings', 'sharedStrings.xml') unless @workbook.shared_strings_empty?

        # Add vbaProject if present.
        if @workbook.vba_project
          rels.add_ms_package_relationship('/vbaProject', 'vbaProject.bin')
        end

        # Add the metadata file if required.
        rels.add_document_relationship('/sheetMetadata', 'metadata.xml') if @workbook.has_metadata?

        rels.set_xml_writer("#{@package_dir}/xl/_rels/workbook.xml.rels")
        rels.assemble_xml_file
      end

      #
      # Write the worksheet .rels files for worksheets that contain links to external
      # data such as hyperlinks or drawings.
      #
      def write_worksheet_rels_files
        @workbook.worksheets.write_worksheet_rels_files(@package_dir)
      end

      #
      # Write the chartsheet .rels files for links to drawing files.
      #
      def write_chartsheet_rels_files
        @workbook.worksheets.write_chartsheet_rels_files(@package_dir)
      end

      #
      # Write the drawing .rels files for worksheets that contain charts or drawings.
      #
      def write_drawing_rels_files
        @workbook.worksheets.write_drawing_rels_files(@package_dir)
      end


      #
      # Write the /xl/media/image?.xml files.
      #
      def add_image_files
        dir = "#{@package_dir}/xl/media"

        @workbook.images.each_with_index do |image, index|
          FileUtils.mkdir_p(dir)
          FileUtils.cp(image[0], "#{dir}/image#{index+1}.#{image[1]}")
        end
      end

      #
      # Write the vbaProject.bin file.
      #
      def add_vba_project
        dir = @package_dir
        vba_project = @workbook.vba_project

        return unless vba_project

        FileUtils.mkdir_p("#{dir}/xl")
        FileUtils.copy(vba_project, "#{dir}/xl/vbaProject.bin")
      end
    end
  end
end
