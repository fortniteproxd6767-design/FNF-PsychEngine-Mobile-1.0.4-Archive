local curState = 0

function onCreate()
    makeLuaSprite('streetBG', 'hazard/qt-port/stage/streetBack', -750, -145)
    addLuaSprite('streetBG', false)

    makeLuaSprite('streetGround', 'hazard/qt-port/stage/streetFront', -820, 720)
    scaleObject('streetGround', 1.15, 1.15)
    addLuaSprite('streetGround', false)

    makeLuaSprite('streetBackError', 'hazard/qt-port/stage/streetBackError', -750, -145)
    setProperty('streetBackError.visible', false)
    addLuaSprite('streetBackError', false)

    makeLuaSprite('streetError', 'hazard/qt-port/stage/streetError', -750, -145)
    setProperty('streetError.visible', false)
    addLuaSprite('streetError', false)

    makeLuaSprite('streetFrontError', 'hazard/qt-port/stage/streetFrontError', -820, 710)
    scaleObject('streetFrontError', 1.15, 1.15)
    setProperty('streetFrontError.visible', false)
    addLuaSprite('streetFrontError', false)

    makeAnimatedLuaSprite('streetTv', 'hazard/qt-port/stage/TV_V5', -62, 540)
    
    addAnimationByPrefix('streetTv', 'idle', 'TV_Idle', 24, true)
    addAnimationByPrefix('streetTv', 'alert', 'TV_Attention', 24, true)
    addAnimationByPrefix('streetTv', 'error', 'TV_Error', 24, true)
    addAnimationByPrefix('streetTv', '404', 'TV_Bluescreen', 24, true)
    addAnimationByPrefix('streetTv', 'instructions', 'TV_Instructions-Normal', 24, true)
    addAnimationByPrefix('streetTv', 'watch', 'TV_Watchout', 24, true)
    addAnimationByPrefix('streetTv', 'drop', 'TV_Drop', 24, true)
    addAnimationByPrefix('streetTv', 'eye', 'TV_brutality', 24, true)
    addAnimationByPrefix('streetTv', 'eyeLeft', 'TV_eyeLeft', 24, true)
    addAnimationByPrefix('streetTv', 'eyeRight', 'TV_eyeRight', 24, true)
    addAnimationByPrefix('streetTv', 'gl', 'TV_GoodLuck', 24, true)
    addAnimationByPrefix('streetTv', 'sus', 'TV_sus', 24, true)
    addAnimationByPrefix('streetTv', 'heart', 'TV_End', 24, false)
    
    setScrollFactor('streetTv', 0.9, 0.9)
    scaleObject('streetTv', 1.2, 1.2)
    addLuaSprite('streetTv', false)
    playAnim('streetTv', 'idle')
end

function onUpdate(elapsed)
    if curState == 1 then
        if curStep % 2 == 0 then
            setProperty('streetBackError.alpha', 0.7)
        else
            setProperty('streetBackError.alpha', 1)
        end
    end
end

function onEvent(name, v1, v2)
    if name == 'streetBG state' then
        curState = tonumber(v1) or 0
        
        setProperty('streetBG.visible', false)
        setProperty('streetBackError.visible', false)
        setProperty('streetError.visible', false)
        setProperty('streetGround.visible', true)
        setProperty('streetFrontError.visible', false)

        if curState == 0 then
            setProperty('streetBG.visible', true)
            playAnim('streetTv', 'idle', true)
        elseif curState == 1 then
            setProperty('streetBackError.visible', true)
            playAnim('streetTv', 'alert', true)
            cameraShake('game', 0.005, 0.2)
        elseif curState == 2 then
            setProperty('streetError.visible', true)
            setProperty('streetFrontError.visible', true)
            setProperty('streetGround.visible', false)
            playAnim('streetTv', '404', true)
            cameraShake('game', 0.01, 0.5)
        end

    elseif name == 'streetTV state' then
        local anims = {
            'idle', 'instructions', 'gl', 'alert', 'watch', 
            'eye', 'error', '404', 'drop', 'heart', 'sus', 
            'eyeLeft', 'eyeRight'
        }
        
        local state = tonumber(v1) or 0
        if state > 0 and state <= #anims then
            playAnim('streetTv', anims[state], true)
        elseif v1 ~= '' then
            playAnim('streetTv', v1, true)
        end
    end
end
