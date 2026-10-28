def markers: type == "array" and all(.[]; type == "string");
def matches($path; $markers):
  any($markers[]; . as $marker | length > 0 and ($path | contains($marker)));

.plan as $plan | .policy as $policy | .leaf as $leaf |
if ($policy | type == "object" and
    (.riskMarkers | markers) and
    (.allowedLocalBuildMarkers | markers) and
    (.allowedDirectFetchMarkers | markers) and
    (.leafDirectFetchMarkers | type == "object" and all(.[]; markers))) and
  ($leaf | type == "string") and
  ($plan | .complete == true and (.builds | markers) and (.fetches | markers))
then
  reduce ($plan.builds | unique)[] as $drv (
    {allowedLocal: [], direct: [], blocked: []};
    if matches($drv; $policy.allowedLocalBuildMarkers) then .allowedLocal += [$drv]
    elif matches($drv; $policy.allowedDirectFetchMarkers) and
      ($leaf == "" or matches($drv; $policy.leafDirectFetchMarkers[$leaf] // []))
    then .direct += [$drv]
    else .blocked += [$drv] end)
else error("invalid maintenance policy or incomplete Nix plan") end
