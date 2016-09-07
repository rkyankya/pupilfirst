# Imports colleges and universities from a YAML file
#
# The YAML file is expected to be the merged version of YMLs generated by the careers360_crawler.
#
# @see https://github.com/SVdotCO/careers360-crawler
class CollegeImporterService < BaseService
  attr_accessor :source_yml_url, :parsed_data

  def initialize(source_yml_url)
    @source_yml_url = source_yml_url
  end

  def process
    load_data
    rebuild_colleges
  end

  private

  def load_data
    @parsed_data = YAML.load(open(source_yml_url).read)
  end

  def rebuild_colleges
    log "Importing #{parsed_data.count} colleges..."

    colleges = parsed_data.map do |college|
      name = college['name']

      # Skip and log entries where name is blank.
      if name.blank?
        log "Encountered entry with blank name. Skipping. Details follow:\n#{college.to_yaml}"
        next
      end

      # Skip if college is present.
      next if College.find_by(name: name).present?

      create_college(college, name)
    end - [nil]

    log "Successfully created #{colleges.count} colleges."
  end

  def create_college(college, name)
    city = extract_city(college, name)
    state = college['state']
    aka = college['alias']
    established_year = college['established_year']
    website = college['website']
    contact = college['contact']
    university = college['university']

    # Create state and university if they're absent.
    state = create_state(state)
    university = create_university(state, university)

    College.create!(
      name: name,
      city: city,
      state: state,
      also_known_as: aka,
      established_year: established_year,
      website: website,
      contact_numbers: contact,
      replacement_university_id: university.id
    )
  end

  # Extract city name from college name if it isn't available.
  def extract_city(college, name)
    city = college['city']
    city = name.split(',').last&.gsub(/campus/i, '')&.squish if city.blank?
    city
  end

  def create_state(state)
    state = State.find_or_create_by!(name: state) if state.present?
    state
  end

  def create_university(state, university)
    university = university.present? ? ReplacementUniversity.find_or_create_by!(name: university) : OpenStruct.new

    # If university's state isn't set yet, set it as college's state.
    if university.state.blank? && state.present? && university.persisted?
      university.update!(state: state)
    end

    university
  end
end
