import json

filepath = '/Users/steve/Documents/GitHub/MDWriter/MDWriter/Resources/Localizable.xcstrings'
with open(filepath, 'r', encoding='utf-8') as f:
    data = json.load(f)

# Only do "What's New in MDWriter" and the Apple Intelligence ones as requested
translations = {
    "What's New in MDWriter": "MDWriter 新功能",
    "Apple Intelligence": "Apple 智能",
    "Harness the power of on-device AI for polishing, summarizing, translating, and smart tagging.": "利用端侧 AI 的强大功能进行润色、摘要、翻译和智能标记。",
    "Continue": "继续"
}

added_count = 0
for k, trans in translations.items():
    if k not in data['strings']:
        data['strings'][k] = {"extractionState": "manual", "localizations": {}}
    
    if 'localizations' not in data['strings'][k]:
        data['strings'][k]['localizations'] = {}
        
    if 'zh-Hans' not in data['strings'][k]['localizations']:
        data['strings'][k]['localizations']['zh-Hans'] = {}
        
    data['strings'][k]['localizations']['zh-Hans']['stringUnit'] = {
        "state": "translated",
        "value": trans
    }
    
    # ensure it's not marked stale
    if data['strings'][k].get('extractionState') == 'stale':
        data['strings'][k]['extractionState'] = 'manual'
        
    added_count += 1

with open(filepath, 'w', encoding='utf-8') as f:
    json.dump(data, f, indent=2, ensure_ascii=False)
    f.write('\n')

print(f"Successfully added/updated {added_count} WhatsNew translations.")
