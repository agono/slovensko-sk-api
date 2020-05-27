json.cin identity.id.find { |id| id.identifier_type.id == '7' }&.identifier_value
json.tin identity.id.find { |id| id.identifier_type.id == '8' }&.identifier_value

json.organization_id corporate_body.org_id
json.organization_units corporate_body.organization_unit

json.partial! 'iam/identities/corporate_body_name', corporate_body: corporate_body
json.alternative_names corporate_body.corporate_body_alternative_name

json.legal_form { json.partial! 'iam/identities/enumeration', value: corporate_body.legal_form }
json.legal_facts corporate_body.other_legal_facts

json.activities corporate_body.activities

json.established_on corporate_body.establishment.to_s.to_date&.iso8601
json.terminated_on corporate_body.termination.to_s.to_date&.iso8601
json.updated_on corporate_body.date_of_status_change.to_s.to_date&.iso8601