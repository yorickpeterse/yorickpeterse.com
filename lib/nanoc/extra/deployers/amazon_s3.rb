module Nanoc
  module Extra
    module Deployers
      ##
      # Class for deploying nanoc websites using the AWS SDK.
      #
      # When deploying unrecognized files (= files not present in output/) are
      # removed. Uploaded objects are cached according to the max_age option.
      #
      # After deploying all modified files are invalidated in CloudFront.
      #
      class AmazonS3 < Nanoc::Extra::Deployer
        Nanoc::Extra::Deployer.register(
          'Nanoc::Extra::Deployers::AmazonS3',
          :amazon_s3
        )

        ##
        # @see [Nanoc::Extra::Deployer#initialize]
        #
        def initialize(*args)
          super

          require 'aws'
          require 'securerandom'
          require 'pathname'
          require 'mime-types'

          AWS.config(:s3_region => region, :cloudfront_region => region)
        end

        ##
        # Deploys the website.
        #
        def run
          puts 'Gathering remote files'

          to_remove     = bucket.objects.map(&:key)
          to_invalidate = []

          puts 'Uploading files'

          source_files.each do |file|
            key = object_key_for(file)
            obj = bucket.objects[key]

            remote_exists   = obj.exists?
            update_existing = remote_exists && outdated?(obj, file)

            # Write the file if it doesn't exist or is outdated
            if !remote_exists || update_existing
              action(:upload, file)

              upload_file(obj, file)
            end

            to_invalidate.push(key) if update_existing

            to_remove.delete(key) if remote_exists || update_existing
          end

          puts 'Removing stray files'

          to_remove.each do |key|
            action(:delete, key)

            bucket.objects[key].delete
          end

          to_invalidate.concat(to_remove)

          unless to_invalidate.empty?
            puts "Invalidating #{to_invalidate.length} CloudFront objects:"

            # When invalidating index.html files we also want to invalidate the
            # parent directory as CloudFront caches these separately.
            to_invalidate |= index_directories(to_invalidate)

            to_invalidate.each do |key|
              action(:delete, key)
            end

            invalidate_files(to_invalidate)
          end
        end

        ##
        # @param [Array] paths
        # @return [Array]
        #
        def index_directories(paths)
          indexes = paths.select { |file| File.basename(file) == 'index.html' }

          return indexes.map do |file|
            dirname = File.dirname(file)

            dirname == '.' ? '/' : dirname + '/'
          end
        end

        ##
        # @param [AWS::S3::S3Object] object
        # @param [String] local_file
        # @return [TrueClass|FalseClass]
        #
        def outdated?(object, local_file)
          local_mtime = File.mtime(local_file)
          local_md5   = Digest::MD5.hexdigest(File.read(local_file))

          # The etag value contains quotes, so lets get rid of those.
          etag = object.etag[1..-2]

          return local_mtime > object.last_modified && local_md5 != etag
        end

        ##
        # @param [String] text
        #
        def action(type, text)
          indent = '  '

          if type == :delete
            puts indent + '-'.red + " #{text}"
          elsif type == :upload
            puts indent + '+'.green + " #{text}"
          end
        end

        ##
        # @return [Enumerable]
        #
        def source_files
          return Dir[File.join(source_path, '**/*')].select do |path|
            File.file?(path)
          end
        end

        ##
        # @param [String] file
        # @return [String]
        #
        def object_key_for(file)
          return Pathname.new(file).relative_path_from(source_pathname).to_s
        end

        ##
        # @return [Pathname]
        #
        def source_pathname
          return @source_pathname ||= Pathname.new(source_path)
        end

        ##
        # Uploads a new file to S3.
        #
        # @param [AWS::S3::S3Object] object The object to use.
        # @param [String] file The path to the local file to upload.
        #
        def upload_file(object, file)
          handle    = File.open(file, 'r')
          mime_type = MIME::Types.of(file)[0].to_s

          object.write(
            handle,
            :acl           => :public_read,
            :content_type  => mime_type,
            :cache_control => "max-age=#{cache_age}, must-revalidate"
          )
        end

        ##
        # Sends an invalidation request to CloudFront for the specified objects.
        #
        # @param [Array] keys
        #
        def invalidate_files(keys)
          cloudfront = AWS::CloudFront.new
          items      = keys.map do |file|
            file.start_with?('/') ? file : "/#{file}"
          end

          response = cloudfront.client.create_invalidation(
            :distribution_id => cloudfront_distribution,
            :invalidation_batch => {
              :paths            => {:quantity => items.length, :items => items},
              :caller_reference => SecureRandom.hex
            }
          )

          puts "Created invalidation request #{response[:id]}"
        end

        ##
        # @return [AWS::S3]
        #
        def s3
          return @s3 ||= AWS::S3.new
        end

        ##
        # @return [AWS::S3::Bucket]
        #
        def bucket
          return @bucket ||= s3.buckets[bucket_name]
        end

        ##
        # @return [String]
        #
        def region
          return config.fetch(:region)
        end

        ##
        # @return [String]
        #
        def cloudfront_distribution
          return config.fetch(:cloudfront_distribution)
        end

        ##
        # @return [String]
        #
        def bucket_name
          return config.fetch(:bucket)
        end

        ##
        # @return [Fixnum]
        #
        def cache_age
          return config.fetch(:age)
        end
      end # AmazonS3
    end # Deployers
  end # Extra
end # Nanoc
