json.image do
    json.id @template.id
    json.name @template.name
    json.status @template.state.to_s.upcase
    json.progress @template.state == :active ? 100 : 50
end
