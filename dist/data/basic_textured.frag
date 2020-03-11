uniform sampler2D texImage1; 
in vec2 texCoord1;
out vec4 outColor;

void main()
{
   outColor = texture2D(texImage1, texCoord1) * tint; 
}

