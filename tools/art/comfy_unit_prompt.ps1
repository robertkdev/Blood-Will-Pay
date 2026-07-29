param(
	[string]$Server = "http://127.0.0.1:8188",
	[string]$ModelPath = "sdxl-turbo",
	[string]$Prompt = "full body dark gothic fantasy autobattler unit, severe AAA game character portrait sprite, black iron armor, readable silhouette, centered, isolated on flat bright green chroma key background, no floor shadow, no text, no frame, no logo",
	[string]$Negative = "cartoon, cute, anime, chibi, low detail, blurry, noisy, text, watermark, frame, cropped head, cropped feet, extra limbs, messy background, scenery, environment, square backdrop",
	[Int64]$Seed = 2606281010,
	[int]$Width = 768,
	[int]$Height = 768,
	[int]$Steps = 4,
	[double]$Cfg = 1.0,
	[string]$SamplerName = "euler",
	[string]$Scheduler = "normal",
	[string]$FilenamePrefix = "blood_will_pay_unit_art"
)

$workflow = @{
	"1" = @{
		class_type = "DiffusersLoader"
		inputs = @{ model_path = $ModelPath }
	}
	"2" = @{
		class_type = "CLIPTextEncode"
		inputs = @{
			clip = @("1", 1)
			text = $Prompt
		}
	}
	"3" = @{
		class_type = "CLIPTextEncode"
		inputs = @{
			clip = @("1", 1)
			text = $Negative
		}
	}
	"4" = @{
		class_type = "EmptyLatentImage"
		inputs = @{
			width = $Width
			height = $Height
			batch_size = 1
		}
	}
	"5" = @{
		class_type = "KSampler"
		inputs = @{
			model = @("1", 0)
			positive = @("2", 0)
			negative = @("3", 0)
			latent_image = @("4", 0)
			seed = $Seed
			steps = $Steps
			cfg = $Cfg
			sampler_name = $SamplerName
			scheduler = $Scheduler
			denoise = 1.0
		}
	}
	"6" = @{
		class_type = "VAEDecode"
		inputs = @{
			samples = @("5", 0)
			vae = @("1", 2)
		}
	}
	"7" = @{
		class_type = "SaveImage"
		inputs = @{
			images = @("6", 0)
			filename_prefix = $FilenamePrefix
		}
	}
}

$body = @{
	prompt = $workflow
	client_id = "codex-blood-will-pay-art"
} | ConvertTo-Json -Depth 20

$response = Invoke-RestMethod -Uri "$Server/prompt" -Method Post -Body $body -ContentType "application/json" -TimeoutSec 30
$promptId = $response.prompt_id
Write-Output "prompt_id=$promptId"

for ($i = 0; $i -lt 300; $i++) {
	Start-Sleep -Seconds 2
	$history = Invoke-RestMethod -Uri "$Server/history/$promptId" -TimeoutSec 10
	if ($history.PSObject.Properties.Name -contains $promptId) {
		$result = $history.$promptId
		$status = $result.status.status_str
		Write-Output "status=$status"
		if ($result.outputs."7".images) {
			foreach ($image in $result.outputs."7".images) {
				$subfolder = $image.subfolder
				if ([string]::IsNullOrWhiteSpace($subfolder)) {
					Write-Output "output=$($image.filename)"
				} else {
					Write-Output "output=$subfolder/$($image.filename)"
				}
			}
		}
		exit 0
	}
}

throw "Timed out waiting for ComfyUI prompt $promptId"
