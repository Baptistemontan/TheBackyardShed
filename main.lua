local STOREO_JOKER_SLOT_ADDED = 3

local function storeo_count(self, offset)
    local count = offset
    if G.jokers.cards[1] then
        for i = 1, #G.jokers.cards do
            local jok = G.jokers.cards[i]
            if jok.ability.name == self.name and not jok.debuff then
                count = count + 1
            end
        end
    end
    return count
end

local function debuff_math(added_slots, offset)
    return math.max(0, added_slots - math.max(0, G.jokers.config.card_limit - #G.jokers.cards - offset))
end

local function get_debuff_count(self, offset)
    local storeo_cnt = storeo_count(self, offset)
    local total_slot_added = STOREO_JOKER_SLOT_ADDED * storeo_cnt

    return debuff_math(total_slot_added, offset)
end

local function storeo_add_to_deck(self, card, from_debuff)
    G.jokers.config.card_limit = G.jokers.config.card_limit + STOREO_JOKER_SLOT_ADDED
end

local function perma_debuff(jok)
    jok.ability.storeo_perma_debuff = true
end


local function debuff_jok(jok)
    jok.ability.storeo_debuff = true
    jok:set_debuff(true)

    -- hacky fix to counteract the joker reenabling when blind is selected and other possible events
    if not jok.ability.storeo_debuff_fn_replaced then
        local old_set_debuff = jok.set_debuff;
        jok.set_debuff = function(self, should_debuff)
            if self.ability.storeo_debuff then
                return
            end
            old_set_debuff(self, should_debuff)
        end
        jok.ability.storeo_debuff_fn_replaced = true
    end
end

local function reenable_jok(jok)
    jok.ability.storeo_debuff = false
    jok:set_debuff(false)
end

local function storeo_remove_from_deck(self, card, from_debuff)
    local debuffed_count = get_debuff_count(self, 1)
    local to_rebuff = debuff_math(STOREO_JOKER_SLOT_ADDED, 1)
    G.jokers.config.card_limit = G.jokers.config.card_limit - STOREO_JOKER_SLOT_ADDED
    local to_skip = debuffed_count - to_rebuff
    for i = 1, #G.jokers.cards do
        if to_rebuff <= 0 then
            return
        end
        local jok = G.jokers.cards[#G.jokers.cards + 1 - i]
        if jok.ability.name == self.name then
            -- pass self
        elseif jok.ability.storeo_debuff and not jok.ability.storeo_perma_debuff then
            if to_skip > 0 then
                to_skip = to_skip - 1
            else
                if from_debuff then
                    reenable_jok(jok)
                else
                    perma_debuff(jok)
                end
                to_rebuff = to_rebuff - 1
            end
        end
    end
end

local function storeo_update(self, dt)
    if G.STAGE == G.STAGES.RUN then
        local to_debuff = get_debuff_count(self, 0)
        local debuffing = true
        for i = 1, #G.jokers.cards do
            debuffing = to_debuff > 0
            local jok = G.jokers.cards[#G.jokers.cards + 1 - i]
            if jok.ability.name == self.name or jok.ability.storeo_perma_debuff then
                -- pass
            elseif jok.ability.storeo_debuff then
                if debuffing then
                    to_debuff = to_debuff - 1
                else
                    reenable_jok(jok)
                end
            elseif debuffing and not jok.debuff then
                debuff_jok(jok)
                to_debuff = to_debuff - 1
            end
        end
    end
end



SMODS.Joker {
    key = 'storeo',
    loc_txt = {
        name = 'Storage box',
        text = {
            '{C:dark_edition}+3{} Joker Slots but {C:red}disable{} the {C:attention}3{} rightmost jokers',
            'When this joker is removed, permanently disable them'
        }
    },
    -- atlas = 'Jokers',
    pos = { x = 0, y = 0 },
    rarity = 4,
    cost = 20,
    blueprint_compat = false,
    eternal_compat = true,
    perishable_compat = true,
    add_to_deck = storeo_add_to_deck,
    remove_from_deck = storeo_remove_from_deck,
    update = storeo_update
}

SMODS.Back {
    key = 'backshed',
    loc_txt = {
        name = 'Backyard Shed',
        text = {
            'Start with a {C:dark_edition}negative{} copy of {C:joker}Storage Box{}',
            '{C:red}-1{} Joker slot'
        }
    },
    config = {
        joker_slot = -1
    },
    unlocked = true,
    discovered = true,
    apply = function(self)
        G.E_MANAGER:add_event(Event({
            func = function()
                if G.jokers then
                    local card = create_card("Joker", G.jokers, true, 4, nil, nil, "j_tbs_storeo", nil)
                    card:set_edition({ negative = true }, true)
                    card:add_to_deck()
                    G.jokers:emplace(card)
                    return true
                end
            end,
        }))
    end
}
