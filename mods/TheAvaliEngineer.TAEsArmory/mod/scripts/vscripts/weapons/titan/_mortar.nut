untyped 

//		Function declarations
global function CalculateTrajVecs
global function TeleportProjectile

//		Data
//	Struct
global struct MortarFireData {
	vector launchDir
	float speed

	float flightTime
}

//	Settings
const float MORTAR_GRAVITY = 375.0
const float MORTAR_OFFSET = 50.0

//		Functions
/*	Calculate throw direction + velocity for arc with params
 *	See https://github.com/Masterchef365/avali_projectile_path/blob/main/main.pdf
 *	Thanks Seg!
 */
MortarFireData function CalculateFireArc( vector startPos, vector endPos, float maxHeight, float g ) {
	//	Add pos to maxHeight
	maxHeight += max(0, endPos.z - startPos.z)

	//	Calculate offsets
	float xOffset = endPos.x - startPos.x
	float yOffset = endPos.y - startPos.y
	float horizOffset = sqrt(xOffset * xOffset + yOffset * yOffset)
	float vertOffset = endPos.z - startPos.z

	//	Calculate velocity
	float vertSpeed = 2 * sqrt(maxHeight * g)
	float flightTime = (vertSpeed + sqrt(vertSpeed * vertSpeed - 4 * g * vertOffset)) / (2 * g)
	float horizSpeed = horizOffset / flightTime

	float projSpeed = sqrt( vertSpeed * vertSpeed + horizSpeed * horizSpeed )

	//	Find angles
	vector projAngles = VectorToAngles( Vector( horizSpeed, 0.0, vertSpeed ) )
	vector xyAngles = VectorToAngles( Vector( xOffset, yOffset, 0.0 ) )

	vector launchAngles = AnglesCompose( xyAngles, projAngles )

	//	Create direction vector
	vector dir = AnglesToForward( launchAngles )

	//	Create data
	MortarFireData data

	data.launchDir = dir
	data.speed = projSpeed

	data.flightTime = flightTime

	/*
	print("\n[TAEsArmory] CalculateFireArc: Variables\n\tmaxHeight = " + maxHeight + "\n\tvertOffset = "
		+ vertOffset + "\n\thorizOffset = " + horizOffset + "\n\tvertSpeed = " + vertSpeed +
		"\n\tflightTime = " + flightTime + "\n\thorizSpeed = " + horizSpeed + "\n\n")
	//	*/

	//	Return
	return data
}

vector function CalculateTrajVecs( vector startPos, vector endPos, float delay, float g ) {
	//	Calculate offsets
	float xOffset = endPos.x - startPos.x
	float yOffset = endPos.y - startPos.y
	float horizOffset = sqrt(xOffset * xOffset + yOffset * yOffset)
	float vertOffset = endPos.z - startPos.z

	//	Calculate velocity
	float vertSpeed = g*delay + vertOffset/delay
	float horizSpeed = horizOffset/delay
	float projSpeed = sqrt( vertSpeed*vertSpeed + horizSpeed*horizSpeed )

	//	Find angles
	vector projAngles = VectorToAngles( Vector( horizSpeed, 0.0, vertSpeed ) )
	vector xyAngles = VectorToAngles( Vector( xOffset, yOffset, 0.0 ) )

	vector launchAngles = AnglesCompose( xyAngles, projAngles )

	//	Create direction vector
	vector dir = AnglesToForward( launchAngles )
	vector vel = dir * projSpeed

	return vel
}

//	New method - teleport rockets to the new point after a delay
void function TeleportProjectile( entity proj, entity weapon, vector targetPos, float delay ) {
	//		Calculation
	//	Raytraces
	vector startNormal = Normalize( proj.GetVelocity() ) 
	vector endNormal = Vector(0, 0, 1)

	float projSpeed = Length( proj.GetVelocity() )
	float traceRange = projSpeed * delay * 0.5

	vector projPos = proj.GetOrigin()
	vector projTracePos = projPos + startNormal * (traceRange + MORTAR_OFFSET)
	vector targetTracePos = targetPos + endNormal * (traceRange + MORTAR_OFFSET)

	TraceResults resultProj = TraceLine( projPos, projTracePos, [], TRACE_MASK_SOLID, TRACE_COLLISION_GROUP_NONE )
	TraceResults resultTarget = TraceLine( targetPos, targetTracePos, [], TRACE_MASK_SOLID, TRACE_COLLISION_GROUP_NONE )

	//	Calculate delay
	float delayProj = delay
	float delayTarget = delay

	if( resultProj.fraction < 1.0 ) {
		delayProj *= resultProj.fraction
		delayProj -= 0.1
	}

	if( resultTarget.fraction < 1.0 ) {
		delayTarget *= resultTarget.fraction
		delayTarget += 0.1

		targetTracePos = resultTarget.endPos
	}

	delayTarget = delay - delayTarget
	targetTracePos -= endNormal * MORTAR_OFFSET

	wait delayProj

	//		Projectile handling
	//	Handle projectile deletion
	float fuse = delay*0.5 //+ expect float( proj.s.fuse )
	if( IsValid(proj) )
		proj.Destroy()

	wait delayTarget

	//	Handle projectile creation
	entity owner = weapon.GetWeaponOwner()
	int damageFlags = weapon.GetWeaponDamageFlags()

	entity newProj = weapon.FireWeaponBolt( targetTracePos, -endNormal,
		projSpeed, damageFlags, damageFlags, false, 0 )
	if( newProj ) {
		//	Grenade init
		newProj.SetProjectileLifetime( delay )
	}
}