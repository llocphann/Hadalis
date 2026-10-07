.pragma library

// Only add an effort field when the catalog identifies reasoning support.
// "off" keeps the provider default; GGUF separately supports true instant mode.
function supported(model) {
    if (model?.capabilities?.reasoning !== "supported") return false
    return ["gguf", "openai", "openai-response", "gemini", "anthropic"].includes(model.api_format)
        && !(model.api_format === "gemini" && /image/i.test(model.model))
}

function apply(model, input, effort) {
    if (!supported(model) || !["low", "medium", "high"].includes(effort)) return input
    const data = Object.assign({}, input)
    if (model.api_format === "openai") {
        data.reasoning_effort = effort
        // Reasoning protocols may reject sampling controls. The provider's
        // explicit extraParams remain authoritative for sampling support.
        if (model.extraParams?.temperature === undefined) delete data.temperature
    } else if (model.api_format === "openai-response") {
        data.reasoning = Object.assign({}, data.reasoning ?? {}, {effort: effort})
        if (model.extraParams?.temperature === undefined) delete data.temperature
    } else if (model.api_format === "gemini") {
        data.generationConfig = Object.assign({}, data.generationConfig ?? {})
        const thinking = Object.assign({}, data.generationConfig.thinkingConfig ?? {})
        if (/gemini-3/.test(model.model)) {
            delete thinking.thinkingBudget
            thinking.thinkingLevel = effort
        } else if (/gemini-2\.5/.test(model.model)) {
            thinking.thinkingBudget = {low: 1024, medium: 4096, high: 8192}[effort]
        } else return input
        data.generationConfig.thinkingConfig = thinking
    } else if (model.api_format === "anthropic") {
        if (/claude-(?:opus|sonnet)-(?:4-[6-9]|[5-9])/.test(model.model)) {
            data.thinking = {type: "adaptive"}
            data.output_config = Object.assign({}, data.output_config ?? {}, {effort: effort})
            delete data.temperature
        } else {
            const budget = {low: 1024, medium: 4096, high: 8192}[effort]
            data.thinking = {type: "enabled", budget_tokens: budget}
            data.max_tokens = Math.max(Number(data.max_tokens) || 4096, budget + 1024)
            data.temperature = 1
        }
    }
    return data
}
