-- Bootstrap do cliente. Vive em StarterPlayerScripts; os controllers ficam na
-- pasta Client ao lado.

local controllers = script.Parent:WaitForChild("Client")

require(controllers.HudController).Init()
require(controllers.EnemyVisuals).Init()
require(controllers.FigureAnimator).Init()
require(controllers.StageController).Init()
require(controllers.ShopController).Init()
require(controllers.CharacterShopController).Init()
require(controllers.RebirthController).Init()
require(controllers.PetShopController).Init()
require(controllers.ClickController).Init()

print("[ClientMain] Cliente pronto.")
