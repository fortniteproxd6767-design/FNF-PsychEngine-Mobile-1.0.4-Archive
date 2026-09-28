local middle = false
local pusing = false
local fogLength = 20
local fogSpeed = {}
function onCreate()
    middle = getPropertyFromClass('ClientPrefs','middleScroll')
    setPropertyFromClass('ClientPrefs','middleScroll',true)

    makeAnimatedLuaSprite('depthsBG','hazard/inhuman-port/backPulsing',-590,-250)
    scaleObject('depthsBG',2.2,2.2)
    addAnimationByPrefix('depthsBG','pulse','kbBACK-pulse',24,false)
    addLuaSprite('depthsBG',false)

    makeLuaSprite('depthsBGDark',nil,-screenWidth,-screenHeight)
    makeGraphic('depthsBGDark',screenWidth*3,screenHeight*3,'000000')
    if songName ~= 'Interlope' then
        setProperty('depthsBGDark.alpha',0.01)
    else
        setProperty('depthsBGDark.alpha',1)
    end
    addLuaSprite('depthsBGDark',true)

    for fog = 1,fogLength do
        makeLuaSprite('depthsFog'..fog,'hazard/inhuman-port/fogEffectTEST'..math.random(1,3),(fog*204)-1250,40 + math.random(-24,24))
        setScrollFactor('depthsFog'..fog,0.1,0.1)
        scaleObject('depthsFog'..fog,2,2)
        setProperty('depthsFog'..fog..'.alpha',0.5)
        addLuaSprite('depthsFog'..fog,false)
        table.insert(fogSpeed,math.random(1,5))
    end
end
function onUpdate(el)
    setProperty('depthsBG.x',-590 + (math.sin((getSongPosition()/2)/(stepCrochet*8)) * 100))
    for fog = 1,fogLength do
        local name = 'depthsFog'..fog
        local fogX = getProperty(name..'.x')
        setProperty(name..'.x',fogX + ((fogSpeed[fog] * 10) * el))
        if fogX >= 2000 then
            setProperty(name..'.x',fogX - 4000)
            setProperty(name..'.y',40 + math.random(-24,24))
        end
    end
end
function onDestroy()
    setPropertyFromClass('ClientPrefs','middleScroll',middle)
end
function onSongStart()
    if songName == 'Interlope' then
        doTweenAlpha('depthsDark','depthsBGDark',0.5,21,'linear')
    end
end
function onBeatHit()
    if pusing then
        objectPlayAnimation('depthsBG','pulse',true)
    end
end
function onEvent(name,v1,v2)
    if name == 'InterlopeEffect' or name == '??????' then
        if v2 == '5' then
            cancelTween('depthsDark')
            setProperty('depthsBGDark.alpha',0.75)
        elseif v2 == '6' then
            setProperty('depthsBGDark.alpha',0)
        elseif v2 == '10' or v2 == '16'  then
            pusing = false
        elseif v2 == '9' or v2 == '11' or v2 == '12' then
            pusing = true
        elseif v2 == '13' then
            doTweenAlpha('depthsDark','depthsBGDark',0.5,2.7,'linear')
            pusing = false
        elseif v2 == '15' then
            doTweenAlpha('depthsDark','depthsBGDark',1,0.4,'linear')
        end
    end
end