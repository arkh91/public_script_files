

////////////////////////////////////////
//                                    //
//  This code has been written by:    //
//  https://github.com/arkh91/        //                        
//                                    //
////////////////////////////////////////
//sudo wget https://raw.githubusercontent.com/arkh91/public_script_files/main/vpn_info.js && chmod a+x vpn_info.js

const axios = require('axios');

const serverAddress = 'https://18.171.137.18:70/jal8eBtw20sHiq3g_EJJAQ'; //UK17
const apiKey = 'YOUR_API_KEY';

const getUsage = async () => {
  try {
    // Get access key usage information
    const response = await axios.get(`${serverAddress}/api/v1/access_keys/${apiKey}/usage`);

    // Handle the response
    console.log('Access Key Usage:', response.data);
  } catch (error) {
    // Handle errors
    console.error('Error:', error.message);
  }
};

// Run the function
getUsage();
