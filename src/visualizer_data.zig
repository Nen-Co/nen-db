const std = @import("std");
const File = std.fs.File;

/// Load visualizer data from JSON file
pub fn loadVisualizerData(allocator: std.mem.Allocator) ![]const u8 {
    const file_path = "pancreatic_cancer_full_data.json";

    const file = std.fs.cwd().openFile(file_path, .{}) catch {
        // If file doesn't exist, return sample data
        return try getSampleData(allocator);
    };
    defer file.close();

    const file_size = try file.getEndPos();
    const contents = try allocator.alloc(u8, file_size);
    _ = try file.readAll(contents);

    return contents;
}

/// Get sample data as fallback
fn getSampleData(allocator: std.mem.Allocator) ![]const u8 {
    const sample_data =
        \\{"nodes":[
        \\{"id":"pancreatic_cancer","label":"Pancreatic Cancer","group":"disease"},
        \\{"id":"KRAS","label":"KRAS","group":"gene"},
        \\{"id":"TP53","label":"TP53","group":"gene"},
        \\{"id":"BRCA2","label":"BRCA2","group":"gene"},
        \\{"id":"CDKN2A","label":"CDKN2A","group":"gene"},
        \\{"id":"SMAD4","label":"SMAD4","group":"gene"},
        \\{"id":"erlotinib","label":"Erlotinib","group":"drug"},
        \\{"id":"gemcitabine","label":"Gemcitabine","group":"drug"},
        \\{"id":"chemotherapy","label":"Chemotherapy","group":"treatment"},
        \\{"id":"metastasis","label":"Metastasis","group":"process"},
        \\{"id":"apoptosis","label":"Apoptosis","group":"process"},
        \\{"id":"MAPK_pathway","label":"MAPK Pathway","group":"pathway"},
        \\{"id":"diabetes","label":"Diabetes","group":"comorbidity"},
        \\{"id":"jaundice","label":"Jaundice","group":"symptom"},
        \\{"id":"pain","label":"Pain","group":"symptom"},
        \\{"id":"CA19-9","label":"CA19-9","group":"biomarker"},
        \\{"id":"insulin","label":"Insulin","group":"hormone"},
        \\{"id":"TGF-beta","label":"TGF-β","group":"protein"},
        \\{"id":"cell_cycle","label":"Cell Cycle","group":"process"}
        \\],"edges":[
        \\{"source":"pancreatic_cancer","target":"KRAS","label":"mutated_in"},
        \\{"source":"pancreatic_cancer","target":"TP53","label":"mutated_in"},
        \\{"source":"pancreatic_cancer","target":"BRCA2","label":"mutated_in"},
        \\{"source":"pancreatic_cancer","target":"CDKN2A","label":"mutated_in"},
        \\{"source":"pancreatic_cancer","target":"SMAD4","label":"mutated_in"},
        \\{"source":"KRAS","target":"MAPK_pathway","label":"activates"},
        \\{"source":"TP53","target":"apoptosis","label":"regulates"},
        \\{"source":"BRCA2","target":"erlotinib","label":"interacts_with"},
        \\{"source":"CDKN2A","target":"MAPK_pathway","label":"inhibits"},
        \\{"source":"SMAD4","target":"TP53","label":"underexpressed_in"},
        \\{"source":"erlotinib","target":"metastasis","label":"inhibits"},
        \\{"source":"gemcitabine","target":"cell_cycle","label":"biomarker_for"},
        \\{"source":"chemotherapy","target":"apoptosis","label":"suppresses"},
        \\{"source":"metastasis","target":"MAPK_pathway","label":"treats"},
        \\{"source":"metastasis","target":"apoptosis","label":"mutated_in"},
        \\{"source":"diabetes","target":"erlotinib","label":"suppresses"},
        \\{"source":"jaundice","target":"pain","label":"activates"},
        \\{"source":"insulin","target":"CA19-9","label":"biomarker_for"},
        \\{"source":"insulin","target":"apoptosis","label":"underexpressed_in"},
        \\{"source":"TGF-beta","target":"KRAS","label":"inhibits"},
        \\{"source":"cell_cycle","target":"CA19-9","label":"treats"},
        \\{"source":"pancreatic_cancer","target":"diabetes","label":"associated_with"},
        \\{"source":"pancreatic_cancer","target":"jaundice","label":"causes"},
        \\{"source":"pancreatic_cancer","target":"CA19-9","label":"biomarker_for"}
        \\],"metadata":{"node_count":19,"edge_count":24,"utilization":15.2}}
    ;

    return allocator.dupe(u8, sample_data);
}
